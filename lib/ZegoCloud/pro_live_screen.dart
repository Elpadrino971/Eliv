import 'dart:async';

import 'package:artist/Animation/heart_animation.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/point_packs.dart';
import 'package:artist/Global/mux.dart';
import 'package:artist/Global/orientation_helper.dart';
import 'package:artist/Global/screen_guard.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_chat_preview.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_side_actions.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_top_bar.dart';
import 'package:artist/ZegoCloud/zego_gifts.dart';
import 'package:artist/widgets/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

/// État du lecteur du direct « pro ».
enum _ProLiveState {
  /// Première connexion au flux (poster + spinner).
  loading,

  /// Le manifest Mux répond 404 / 412 : la régie n'envoie pas (encore)
  /// d'image. Réessai automatique toutes les 5 s.
  waiting,

  /// Le flux est lu.
  playing,

  /// Coupure (réseau, erreur du lecteur, flux figé) : reconnexion auto.
  reconnecting,

  /// Le concert est terminé (statut `completed` au polling).
  ended,
}

/// Écran fan d'un concert en mode « pro » : une régie vidéo (OBS / ATEM)
/// envoie l'image vers Mux, le fan regarde le HLS faible latence
/// (`https://stream.mux.com/<mux_live_playback_id>.m3u8`).
///
/// Même interface que [JoinStream] (en-tête compact, bouton œil, chat,
/// actions latérales, cadeaux) mais SANS ZegoCloud : chat, cadeaux et likes
/// passent uniquement par le backend, et le fil est rafraîchi toutes les
/// 15 s (`getEventLogs`), comme sur l'écran Zego.
class ProLiveScreen extends StatefulWidget {
  const ProLiveScreen({super.key, required this.event});
  final Event event;

  @override
  State<ProLiveScreen> createState() => _ProLiveScreenState();
}

class _ProLiveScreenState extends State<ProLiveScreen>
    with WidgetsBindingObserver {
  final EventController eventController = Get.put(EventController());
  final TextEditingController commentController = TextEditingController();
  final GlobalKey<HeartAnimationOverlayState> _heartKey =
      GlobalKey<HeartAnimationOverlayState>();

  late Event currentEvent;

  VideoPlayerController? _controller;
  _ProLiveState _state = _ProLiveState.loading;

  // Une connexion (sonde du manifest + initialize) est en cours.
  bool _connecting = false;
  // L'app est en arrière-plan : pas de lecture ni de reconnexion.
  bool _backgrounded = false;
  bool _disposed = false;
  // Le flux a déjà été lu au moins une fois (change le message d'attente :
  // « pas encore commencé » vs « momentanément coupé »).
  bool _everPlayed = false;
  // Plein écran paysage (vidéo seule).
  bool _landscape = false;
  // Le like backend n'est envoyé qu'une fois par visite (les cœurs suivants
  // restent des animations locales).
  bool _likeSent = false;

  // Surveillance d'un flux figé (lecture arrêtée / mise en mémoire tampon
  // interminable).
  DateTime? _bufferingSince;
  int _stallTicks = 0;

  Timer? _retryTimer;
  Timer? _logTimer;
  Timer? _watchdogTimer;

  // Mode « place à la scène » : même préférence que l'écran Zego.
  bool _overlayHidden = box.read('fan_overlay_hidden') == true;

  static const Duration _retryDelay = Duration(seconds: 5);

  bool _isEndedStatus(String? status) =>
      status == 'completed' || status == 'ended';

  /// L'artiste du concert regarde son propre direct (pas de cœur / cadeau,
  /// accès aux stats comme sur son écran de live).
  bool get _isOwner {
    final uid = userModel.value.user?.id;
    return uid != null && currentEvent.artistId == uid;
  }

  @override
  void initState() {
    super.initState();
    // Concert : captures / enregistrements d'écran noirs (voir screen_guard.dart).
    protectScreen(true);
    refreshPurchasablePointPacks();
    currentEvent = widget.event;
    WidgetsBinding.instance.addObserver(this);
    // Jamais deux vidéos en même temps : on ferme un mini-lecteur éventuel.
    if (Get.isRegistered<MiniPlayerController>() &&
        MiniPlayerController.to.controller.value != null) {
      MiniPlayerController.to.close();
    }
    if (_isEndedStatus(currentEvent.status)) {
      _state = _ProLiveState.ended;
    } else {
      _connect();
      _watchdogTimer = Timer.periodic(
        _retryDelay,
        (_) => _watchdog(),
      );
    }
    _initFeed();
  }

  @override
  void dispose() {
    protectScreen(false);
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _logTimer?.cancel();
    _watchdogTimer?.cancel();
    final c = _controller;
    _controller = null;
    c?.removeListener(_onPlayerValue);
    c?.dispose();
    commentController.dispose();
    if (_landscape) OrientationHelper.resetPortrait();
    super.dispose();
  }

  // ── Fil (chat / cadeaux) + statut ─────────────────────────────────────

  Future<void> _initFeed() async {
    await eventController.getAbusiveWords();
    final data = await eventController.getEventLogs(
      eventId: currentEvent.id.toString(),
    );
    if (!mounted) return;
    if (data != null) {
      setState(() {
        currentEvent = currentEvent.copyWith(activities: data);
      });
    }
    await eventController.getGifts();
    if (!mounted || _state == _ProLiveState.ended) return;
    // 15 s, comme l'écran Zego. Annulé dans dispose() et à la fin du live.
    _logTimer?.cancel();
    _logTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _poll();
    });
  }

  Future<void> _poll() async {
    final data = await eventController.getEventLogs(
      eventId: currentEvent.id.toString(),
    );
    if (!mounted) return;
    if (data != null) {
      setState(() {
        currentEvent = currentEvent.copyWith(activities: data);
      });
    }
    await _refreshEvent();
  }

  Future<Event?> _fetchEvent() async {
    try {
      return await eventController.getEventById(currentEvent.id.toString());
    } catch (e) {
      myPrint('ProLive: getEventById -> $e');
      return null;
    }
  }

  /// Relit le concert (statut, playback id). Passe en « terminé » quand le
  /// backend a basculé le statut à `completed` (la régie a arrêté).
  Future<void> _refreshEvent() async {
    final Event? fresh = await _fetchEvent();
    if (!mounted || _disposed || fresh == null) return;
    setState(() {
      currentEvent = currentEvent.copyWith(
        status: fresh.status,
        muxLivePlaybackId: fresh.muxLivePlaybackId,
      );
    });
    if (_isEndedStatus(fresh.status)) _onEnded();
  }

  void _onEnded() {
    if (_state == _ProLiveState.ended) return;
    _retryTimer?.cancel();
    _logTimer?.cancel();
    _watchdogTimer?.cancel();
    _dropPlayer();
    if (_landscape) _setLandscape(false);
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) setState(() => _state = _ProLiveState.ended);
  }

  // ── Lecteur HLS ───────────────────────────────────────────────────────

  /// Code HTTP du manifest (null si réseau indisponible). Mux répond 412 /
  /// 404 tant que la régie n'envoie pas d'image.
  Future<int?> _probeManifest(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      return res.statusCode;
    } catch (e) {
      myPrint('ProLive: manifest -> $e');
      return null;
    }
  }

  bool get _shouldStop =>
      !mounted || _disposed || _backgrounded || _state == _ProLiveState.ended;

  Future<void> _connect() async {
    if (_connecting || _shouldStop) return;
    _connecting = true;
    _retryTimer?.cancel();
    try {
      String? playbackId = currentEvent.muxLivePlaybackId;
      if (playbackId == null || playbackId.isEmpty) {
        // Les listes d'events ne portent pas toujours le playback id : on
        // relit le concert.
        await _refreshEvent();
        playbackId = currentEvent.muxLivePlaybackId;
      }
      if (_shouldStop) return;
      if (playbackId == null || playbackId.isEmpty) {
        _showWaiting();
        return;
      }

      final url = Mux.hlsUrl(playbackId);
      final code = await _probeManifest(url);
      if (_shouldStop) return;
      if (code == 404 || code == 412) {
        _showWaiting();
        return;
      }
      if (code != 200) {
        _showReconnecting();
        return;
      }

      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await c.initialize();
      } catch (e) {
        myPrint('ProLive: initialize -> $e');
        await c.dispose();
        if (!_shouldStop) _showReconnecting();
        return;
      }
      if (_shouldStop) {
        await c.dispose();
        return;
      }
      // Remplace l'ancien lecteur (reprise après arrière-plan : il est
      // resté affiché, figé, jusqu'ici).
      _dropPlayer();
      c.addListener(_onPlayerValue);
      _controller = c;
      _everPlayed = true;
      _stallTicks = 0;
      _bufferingSince = null;
      setState(() => _state = _ProLiveState.playing);
      c.play();
    } finally {
      _connecting = false;
    }
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    if (_disposed || _state == _ProLiveState.ended) return;
    _retryTimer = Timer(delay, () {
      // Une connexion lancée entre-temps (retour au premier plan) a pu
      // aboutir : inutile de recréer le lecteur.
      if (!_backgrounded && _state != _ProLiveState.playing) _connect();
    });
  }

  void _showWaiting() {
    _dropPlayer();
    if (mounted) setState(() => _state = _ProLiveState.waiting);
    _scheduleRetry(_retryDelay);
  }

  void _showReconnecting() {
    _dropPlayer();
    if (mounted) setState(() => _state = _ProLiveState.reconnecting);
    _scheduleRetry(_retryDelay);
  }

  /// Coupure en cours de lecture : on libère le lecteur, on vérifie le
  /// statut (la régie a peut-être terminé) et on retente rapidement.
  void _reconnect() {
    if (_disposed || _state == _ProLiveState.ended) return;
    _dropPlayer();
    if (mounted) setState(() => _state = _ProLiveState.reconnecting);
    _refreshEvent();
    _scheduleRetry(const Duration(seconds: 2));
  }

  /// Retire le lecteur de l'arbre puis le libère après la frame (le widget
  /// VideoPlayer ne doit plus l'utiliser au moment du dispose).
  void _dropPlayer() {
    final old = _controller;
    if (old == null) return;
    old.removeListener(_onPlayerValue);
    _controller = null;
    _bufferingSince = null;
    _stallTicks = 0;
    if (mounted && !_disposed) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    } else {
      old.dispose();
    }
  }

  void _onPlayerValue() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (v.hasError) {
      myPrint('ProLive: erreur lecteur -> ${v.errorDescription}');
      _reconnect();
      return;
    }
    if (v.isBuffering) {
      _bufferingSince ??= DateTime.now();
    } else {
      _bufferingSince = null;
    }
  }

  /// Toutes les 5 s : relance un flux arrêté, reconnecte un flux figé.
  void _watchdog() {
    final c = _controller;
    if (c == null || _backgrounded || _state != _ProLiveState.playing) {
      _stallTicks = 0;
      return;
    }
    final v = c.value;
    final since = _bufferingSince;
    final stuckBuffering = since != null &&
        DateTime.now().difference(since) > const Duration(seconds: 20);
    // Fin de playlist (la régie a coupé, Mux a clos le flux) : un play()
    // relirait depuis le début de la fenêtre, on se reconnecte plutôt.
    final atEnd = !v.isPlaying &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(seconds: 1);
    if (!v.isPlaying || stuckBuffering) {
      _stallTicks++;
      if (_stallTicks == 1 && !v.isPlaying && !stuckBuffering && !atEnd) {
        c.play(); // simple relance d'abord
      } else if (_stallTicks >= 3 || stuckBuffering || atEnd) {
        _reconnect();
      }
    } else {
      _stallTicks = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pas de lecture en arrière-plan.
    if (state == AppLifecycleState.paused) {
      _backgrounded = true;
      _retryTimer?.cancel();
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (!_backgrounded) return;
      _backgrounded = false;
      if (_state == _ProLiveState.ended) return;
      // On recrée le lecteur pour repartir au bord du direct (sans rattraper
      // le retard accumulé pendant la pause), et on relit le statut.
      _refreshEvent();
      _connect();
    }
  }

  // ── Actions fan (backend uniquement, pas de Zego) ────────────────────

  Future<void> _sendComment() async {
    final String comment = commentController.text.trim();
    if (comment.isEmpty) return;

    if (eventController.hasAbusiveWords(comment)) {
      myWarningDialog(subtitle: 'live_restricted_words'.tr);
      return;
    }
    commentController.clear();

    final updated = await eventController.getEventComments(
      eventId: currentEvent.id.toString(),
      comment: comment,
    );
    if (updated != null && mounted) {
      setState(() {
        currentEvent = currentEvent.copyWith(activities: updated);
      });
    }
  }

  void _onHeartTap() {
    _heartKey.currentState?.addHeart();
    if (_likeSent || currentEvent.id == null) return;
    _likeSent = true;
    eventController.likeEvent(
      eventId: currentEvent.id.toString(),
      liked: true,
    );
  }

  void _openGifts() {
    Get.bottomSheet(
      ZegoGifts(
        eventId: currentEvent.id.toString(),
        broadcastToZego: false,
        onGiftSent: (activities) {
          if (!mounted) return;
          setState(() {
            currentEvent = currentEvent.copyWith(activities: activities);
          });
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _setLandscape(bool value) {
    if (_landscape == value) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) setState(() => _landscape = value);
    if (value) {
      OrientationHelper.forceLandscape();
    } else {
      OrientationHelper.resetPortrait();
    }
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    Get.back();
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return CaptureShield(child: Scaffold(
      backgroundColor: blackColor,
      // Le clavier ne redimensionne pas la vidéo : seul l'overlay remonte.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _videoLayer(),
          IgnorePointer(child: HeartAnimationOverlay(key: _heartKey)),
          if (_state == _ProLiveState.ended)
            _endedLayer()
          else if (_landscape)
            _landscapeControls()
          else
            _buildOverlayUI(keyboard),
        ],
      ),
    ));
  }

  Widget _videoLayer() {
    final c = _controller;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // La régie envoie du 16:9 : affichage « contain » centré sur fond
          // noir (bouton plein écran pour passer en paysage).
          if (c != null && c.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio > 0
                    ? c.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(c),
              ),
            )
          else
            _poster(),
          if ((c == null || !c.value.isInitialized) &&
              _state != _ProLiveState.ended)
            _statusMessage(),
        ],
      ),
    );
  }

  Widget _poster() {
    final cover = (currentEvent.coverImage ?? '').trim();
    final url = cover.isEmpty
        ? ''
        : (cover.startsWith('http') ? cover : '${APIs.eventImageIP}/$cover');
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url.isNotEmpty)
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        Container(color: Colors.black.withValues(alpha: 0.6)),
      ],
    );
  }

  Widget _statusMessage() {
    final String title;
    final String? subtitle;
    if (_state == _ProLiveState.waiting && !_everPlayed) {
      title = 'pro_waiting_title'.tr;
      subtitle = 'pro_waiting_sub'.tr;
    } else if (_state == _ProLiveState.waiting ||
        _state == _ProLiveState.reconnecting) {
      title = 'pro_reconnecting'.tr;
      subtitle = 'pro_reconnecting_sub'.tr;
    } else {
      title = 'pro_loading'.tr;
      subtitle = null;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: goldPrimary),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ivory,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: textMuted, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _endedLayer() {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.music_note_rounded,
                  color: goldPrimary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'pro_ended_title'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ivory,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'pro_ended_sub'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textMuted, fontSize: 14),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _close,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: goldPrimary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'pro_close'.tr,
                      style: const TextStyle(
                        color: midnightPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Petit bouton rond (même style que l'écran Zego).
  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: active ? goldPrimary : Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? midnightPrimary : ivory,
        ),
      ),
    );
  }

  Widget _landscapeControls() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'pro_exit_fullscreen'.tr,
                child: _roundButton(
                  icon: Icons.fullscreen_exit_rounded,
                  onTap: () => _setLandscape(false),
                ),
              ),
              _roundButton(icon: Icons.close_rounded, onTap: _close),
            ],
          ),
        ),
      ),
    );
  }

  Widget _commentField() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: goldSecondary.withValues(alpha: 0.35)),
            ),
            child: TextField(
              controller: commentController,
              style: const TextStyle(color: ivory, fontSize: 14),
              cursorColor: goldPrimary,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendComment(),
              decoration: InputDecoration(
                hintText: 'pro_comment_hint'.tr,
                hintStyle: const TextStyle(color: textMuted, fontSize: 14),
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sendComment,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: const BoxDecoration(
              color: goldPrimary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.send_rounded,
              color: midnightPrimary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlayUI(double keyboard) {
    final bool keyboardOpen = keyboard > 0;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // En-tête compact (artiste · LIVE · titre) + œil + plein écran +
            // fermer. Les boutons restent TOUJOURS visibles.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Expanded(
                    child: _overlayHidden
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: LiveStreamTopBar(
                              event: currentEvent,
                              isLive: currentEvent.status == 'live',
                            ),
                          ),
                  ),
                  Opacity(
                    opacity: _overlayHidden ? 0.4 : 1,
                    child: Tooltip(
                      message: 'fan_clean_view'.tr,
                      child: _roundButton(
                        icon: _overlayHidden
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        active: !_overlayHidden,
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() => _overlayHidden = !_overlayHidden);
                          box.write('fan_overlay_hidden', _overlayHidden);
                        },
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'pro_fullscreen'.tr,
                    child: _roundButton(
                      icon: Icons.fullscreen_rounded,
                      onTap: () => _setLandscape(true),
                    ),
                  ),
                  _roundButton(icon: Icons.close_rounded, onTap: _close),
                ],
              ),
            ),

            const Spacer(),

            // Chat + actions + champ d'envoi (masqués en mode épuré). Clavier
            // ouvert : fil réduit et actions masquées pour ne pas déborder.
            if (!_overlayHidden)
              Padding(
                padding: myPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: keyboardOpen ? 120 : 250,
                            child: LiveStreamChatPreview(
                              messages: currentEvent.activities ?? [],
                            ),
                          ),
                        ),
                        if (!keyboardOpen) ...[
                          const SizedBox(width: 8),
                          LiveStreamSideActions(
                            event: currentEvent,
                            activities: currentEvent.activities ?? [],
                            fromArtist: _isOwner,
                            onGiftTap: _openGifts,
                            onHeartTap: _onHeartTap,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    _commentField(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
