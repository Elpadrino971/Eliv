import 'dart:async';

import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/live_router.dart';
import 'package:artist/Global/mux.dart';
import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/BottomBar/screens/LiveScreen/create_short_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/featured_event_sheet.dart';
import 'package:artist/widgets/replay_player_screen.dart';
import 'package:artist/widgets/feed_poster.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/section_header.dart';
import 'package:artist/widgets/upcoming_event_tile.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// Formate une duree video en m:ss (ou h:mm:ss si > 1h).
String _fmtDur(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final m = two(d.inMinutes.remainder(60));
  final s = two(d.inSeconds.remainder(60));
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

/// Onglet Live = 3 pages en swipe horizontal :
///  - Page 0 "Pour toi" : feed vertical de reels (VybzzZ Originals)
///  - Page 1 "En direct" : lives en cours, apercu gratuit 60s puis gate opaque
///  - Page 2 "Clips" : feed vertical des shorts UGC (uploadés via Mux)
///
/// ── Audit mémoire des lecteurs vidéo (lot 6) ──
/// AVANT : « Pour toi » = 1 lecteur HLS (EventController.currentController),
/// recréé à chaque swipe (init réseau complète -> démarrage lent, écran noir
/// entre deux clips) ; « Clips » = 1 lecteur idem. Les deux feeds ne
/// coexistent jamais (PageView horizontal sans keep-alive : la page qui sort
/// de l'écran est détruite, son lecteur libéré dans dispose()). En
/// arrière-plan (téléphone verrouillé) : AUCUNE pause — avec
/// UIBackgroundModes=audio, le clip continuait à jouer, tampons HLS +
/// décodeur conservés -> l'app suspendue restait lourde et iOS la tuait
/// (relance à froid sur le splash).
/// APRÈS : chaque feed garde au plus 2 lecteurs (courant + suivant préchargé,
/// jamais lu avant d'être promu), le précédent est libéré au swipe, et TOUS
/// les lecteurs sont libérés au passage en arrière-plan puis recréés au
/// retour (même clip, même position). Poster Mux (720 px) par-dessus la vidéo
/// tant que la première image n'est pas rendue. Aucun await dans build.
/// Le PageView vertical de chaque feed n'utilise ni keepPage utile ni
/// AutomaticKeepAliveClientMixin (pages détruites hors écran). Quand on
/// quitte l'onglet Live (Accueil/Profil…), MyBottomBar remplace l'écran :
/// tout est libéré.
class VybzLiveScreen extends StatefulWidget {
  const VybzLiveScreen({super.key});

  @override
  State<VybzLiveScreen> createState() => _VybzLiveScreenState();
}

class _VybzLiveScreenState extends State<VybzLiveScreen> {
  final eventController = Get.find<EventController>();
  final PageController _hController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _hController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _hController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      body: Stack(
        children: [
          PageView(
            controller: _hController,
            onPageChanged: (i) {
              setState(() => _page = i);
              // Met en pause le reel quand on quitte "Pour toi".
              final c = eventController.currentController.value;
              if (c != null && c.value.isInitialized) {
                i == 0 ? c.play() : c.pause();
              }
            },
            children: [
              const _ForYouFeed(),
              _LivesFeed(onGoForYou: () => _goTo(0)),
              _ClipsFeed(isActive: _page == 2),
            ],
          ),

          // Pastille de navigation centrale (Pour toi · En direct)
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 0,
            right: 0,
            child: Obx(() {
              // Les onglets restent TOUJOURS visibles : l'application s'ouvre
              // sur cet écran, et les masquer laissait l'utilisateur sans
              // aucun repère ni moyen d'en sortir.
              eventController.showVideoControls.value; // dépendance Obx conservée
              return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: blackColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: whiteColor.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tab('live_tab_for_you'.tr, 0),
                    _tab('live_tab_live'.tr, 1, live: true),
                    _tab('Clips', 2),
                  ],
                ),
              ),
            );
            }),
          ),

          // X de sortie sur les pages "En direct" et "Clips" : l'onglet Live
          // masque la barre de nav, donc sans ça on reste coincé. Même action
          // que le X de "Pour toi".
          if (_page != 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 12,
              child: GestureDetector(
                onTap: () => Get.offAll(() => const MyBottomBar()),
                child: const Icon(
                  Icons.close_rounded,
                  color: whiteColor,
                  size: 30,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tab(String label, int index, {bool live = false}) {
    final active = _page == index;
    return GestureDetector(
      onTap: () => _goTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? whiteColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (live)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: liveRed,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: active ? whiteColor : whiteColor.withValues(alpha: 0.55),
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// PAGE 0 — "Pour toi" : feed vertical de reels (logique d'origine conservee)
// ───────────────────────────────────────────────────────────────────────────
class _ForYouFeed extends StatefulWidget {
  const _ForYouFeed();

  @override
  State<_ForYouFeed> createState() => _ForYouFeedState();
}

class _ForYouFeedState extends State<_ForYouFeed> with WidgetsBindingObserver {
  final eventController = Get.find<EventController>();

  /// Vrai pendant le chargement de secours ([_ensureContentLoaded]) : on
  /// affiche alors un spinner (fini) plutôt que l'état vide.
  bool _loading = false;

  // ── Cycle de vie (arrière-plan) ──
  // Les lecteurs de ce feed (courant + suivant préchargé, voir
  // EventController) sont LIBÉRÉS quand l'app passe en arrière-plan
  // (décodeur + tampons HLS = plusieurs dizaines de Mo) et recréés au
  // retour, sur le même clip et à la même position. Moins de mémoire pendant
  // la suspension -> iOS tue moins souvent l'app. Note : Info.plist déclare
  // UIBackgroundModes=audio, sans cette pause le clip continuait à jouer
  // (son) téléphone verrouillé.
  bool _releasedInBackground = false;
  bool _wasPlaying = false;
  Duration _resumeAt = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFirstReel();
    _ensureContentLoaded();
  }

  void _initFirstReel() {
    // Le PageView repart toujours de la page 0 quand ce feed est (re)créé.
    eventController.currentVideoIndex.value = 0;
    final url = eventController.reelUrlAt(0);
    if (url != null) {
      eventController.initVideoPlayer(url);
      eventController.preloadNextVideo(eventController.reelUrlAt(1));
    }
  }

  /// Retour d'arrière-plan : recrée le lecteur du clip affiché (à la
  /// position mémorisée) et relance le préchargement du suivant.
  void _reopenCurrent() {
    final index = eventController.currentVideoIndex.value;
    final url = eventController.reelUrlAt(index);
    if (url == null) return;
    eventController.initVideoPlayer(url, startAt: _resumeAt);
    eventController.preloadNextVideo(eventController.reelUrlAt(index + 1));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = eventController.currentController.value;
    if (state == AppLifecycleState.inactive) {
      // Centre de contrôle, appel entrant, feuille de partage… : simple pause.
      if (c != null && c.value.isInitialized) {
        _wasPlaying = _wasPlaying || c.value.isPlaying;
        c.pause();
      }
    } else if (state == AppLifecycleState.paused) {
      if (c != null && c.value.isInitialized) {
        _wasPlaying = _wasPlaying || c.value.isPlaying;
        _resumeAt = c.value.position;
      }
      // Libère le courant ET le préchargé.
      eventController.disposeVideoController();
      eventController.update();
      _releasedInBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_releasedInBackground) {
        _releasedInBackground = false;
        _reopenCurrent();
        _resumeAt = Duration.zero;
      } else if (_wasPlaying && c != null && c.value.isInitialized) {
        c.play();
      }
      _wasPlaying = false;
    }
  }

  /// « Pour toi » restait vide quand Home n'avait jamais été construit
  /// (c'est Home qui charge les clips et les concerts à venir). On charge
  /// ici ce qui manque — sans doubler si c'est déjà en mémoire.
  Future<void> _ensureContentLoaded() async {
    final hasClips = eventController.forYouClipUrls.isNotEmpty;
    final hasEvents = (eventController.allEvents.value.data ?? []).isNotEmpty;
    if (hasClips || hasEvents) return;
    _loading = true;
    try {
      await eventController.loadFeedClips();
      if ((eventController.allEvents.value.data ?? []).isEmpty) {
        await eventController.getEventsByStatus(
          status: EventStatus.published,
          dateStatus: EventDateStatus.future,
        );
      }
    } catch (e) {
      myPrint('for you feed: $e');
    } finally {
      _loading = false;
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    if (eventController.currentController.value == null) _initFirstReel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    eventController.disposeVideoController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // GetBuilder (et non Obx) : les drapeaux de chargement du contrôleur
    // sont de simples bool, rafraîchis par ses update() après chaque requête.
    return GetBuilder<EventController>(builder: (c) {
      final events = c.allEvents.value.data ?? [];
      final clipUrls = c.forYouClipUrls;
      final hasContent = clipUrls.isNotEmpty || events.isNotEmpty;
      if (!hasContent) {
        // Spinner (fini) tant qu'une requête est en cours ; ensuite, au lieu
        // du seul message « Aucun reel », la carte « À la une » + les
        // concerts à venir.
        final stillLoading = _loading ||
            (!c.feedClipsLoaded && c.isLoadingFeedClips) ||
            (c.allEvents.value.data == null && c.isLoadingUpcoming);
        if (stillLoading) return const _FeedLoading();
        return const _FeedFallback(
          icon: Icons.video_collection_outlined,
          titleKey: 'live_no_reel_t',
          subtitleKey: 'live_no_reel_s',
        );
      }
      return PageView.builder(
              scrollDirection: Axis.vertical,
              onPageChanged: eventController.onPageChanged,
              itemCount: clipUrls.isNotEmpty ? clipUrls.length : events.length,
              itemBuilder: (context, index) {
                // Les clips admin (feed_clips) ne sont pas rattachés à un
                // concert précis : event peut être null (clips purs), le
                // bandeau artiste/concert est alors simplement masqué plus bas.
                final event = events.isNotEmpty
                    ? events[index % events.length]
                    : null;
                return GetBuilder<EventController>(
                  builder: (controller) {
                    final videoController = controller.currentController.value;
                    // Le lecteur courant n'est rattaché qu'à SA page : la
                    // page voisine (visible pendant le swipe) montre son
                    // propre poster, pas la vidéo en cours.
                    final isCurrentPage =
                        controller.currentVideoIndex.value == index;

                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: controller.toggleVideoControls,
                          child: Container(
                            width: Get.width,
                            height: Get.height,
                            color: blackColor,
                            child: _ReelSurface(
                              controller: isCurrentPage ? videoController : null,
                              posterUrl: index < clipUrls.length
                                  ? clipUrls[index]
                                  : null,
                            ),
                          ),
                        ),
                        if (controller.showVideoControls.value &&
                            videoController != null)
                          Positioned.fill(
                            child: Container(
                              color: blackColor.withValues(alpha: 0.3),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.replay_5,
                                            color: whiteColor,
                                            size: 40,
                                          ),
                                          onPressed: () =>
                                              controller.seekVideo(-5),
                                        ),
                                        width(0.05),
                                        IconButton(
                                          icon: Icon(
                                            videoController.value.isPlaying
                                                ? Icons.pause_circle_filled
                                                : Icons.play_circle_filled,
                                            color: whiteColor,
                                            size: 60,
                                          ),
                                          onPressed: () =>
                                              controller.playPauseVideo(),
                                        ),
                                        width(0.05),
                                        IconButton(
                                          icon: Icon(
                                            Icons.forward_5,
                                            color: whiteColor,
                                            size: 40,
                                          ),
                                          onPressed: () =>
                                              controller.seekVideo(5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Jauge scrubbable (glisser pour avancer/reculer)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      150,
                                    ),
                                    child: ValueListenableBuilder<
                                      VideoPlayerValue
                                    >(
                                      valueListenable: videoController,
                                      builder: (context, value, _) {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            VideoProgressIndicator(
                                              videoController,
                                              allowScrubbing: true,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              colors: const VideoProgressColors(
                                                playedColor: goldPrimary,
                                                bufferedColor: Colors.white24,
                                                backgroundColor: Colors.white12,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  _fmtDur(value.position),
                                                  style: const TextStyle(
                                                    color: whiteColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  _fmtDur(value.duration),
                                                  style: TextStyle(
                                                    color: whiteColor
                                                        .withValues(alpha: 0.7),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (controller.showVideoControls.value)
                          Container(
                          padding: myPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              height(0.03),
                              Row(
                                children: [
                                  Text(
                                    'VybzzZ',
                                    style: TextStyle(
                                      color: whiteColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  width(0.01),
                                  Text(
                                    'Originals',
                                    style: TextStyle(
                                      color: greyColor,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Spacer(),
                                  GestureDetector(
                                    onTap: () => myShare(
                                      message: 'share_live_message'.trParams({
                                        'name': event?.name?.capitalize ?? 'VybzzZ',
                                      }),
                                    ),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        color: whiteColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: const Icon(
                                        Icons.ios_share_rounded,
                                        color: whiteColor,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: controller.toggleMute,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: whiteColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Icon(
                                        controller.isMuted.value
                                            ? Icons.volume_off
                                            : Icons.volume_up,
                                        color: whiteColor,
                                        size: 25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              height(0.01),
                            ],
                          ),
                        ),
                        if (controller.showVideoControls.value)
                          Positioned(
                          bottom: 0,
                          left: 0,
                          child: Padding(
                            padding: myPadding,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Clip admin pur (feed_clips sans concert
                                // associé) : pas de bandeau artiste à afficher.
                                if (event != null) ...[
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (event.artist == null) return;
                                        Get.to(
                                          () => ArtistDetailScreen(
                                            artist: event.artist!,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        '@${event.artist?.artistName?.capitalize ?? 'N/A'}',
                                        style: TextStyle(
                                          color: whiteColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    width(0.01),
                                    ((event.artist?.isVerified ?? 0) == 1)
                                        ? Image.asset(
                                            'assets/check_icon2.png',
                                            width: 15,
                                          )
                                        : SizedBox(),
                                  ],
                                ),
                                height(0.01),
                                SizedBox(
                                  width: Get.width * 0.5,
                                  child: Text(
                                    event.name?.capitalize ?? 'N/A',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: whiteColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                height(0.01),
                                SizedBox(
                                  width: Get.width * 0.6,
                                  child: MyButton(
                                    label: 'join_live'.tr,
                                    onTap: () {
                                      Get.to(() => FutureScreen(event: event));
                                    },
                                  ),
                                ),
                                ],
                                height(0.07),
                              ],
                            ),
                          ),
                        ),

                        // Boutons "+" (créer un short) et fermer (X) — placés en
                        // dernier dans le Stack pour rester AU-DESSUS du voile de
                        // contrôles (sinon le Positioned.fill avale leurs taps).
                        if (controller.showVideoControls.value)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 10,
                            right: 12,
                            child: GestureDetector(
                              onTap: () =>
                                  Get.to(() => const CreateShortScreen()),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: goldPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: midnightPrimary,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        // La croix de sortie est TOUJOURS affichée : elle
                        // n'apparaissait qu'après avoir tapé la vidéo au
                        // hasard, ce qui rendait l'écran sans issue visible.
                        if (true)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 10,
                            left: 12,
                            child: GestureDetector(
                              onTap: () =>
                                  Get.offAll(() => const MyBottomBar()),
                              child: const Icon(
                                Icons.close_rounded,
                                color: whiteColor,
                                size: 30,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 8),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
    });
  }
}

// ───────────────────────────────────────────────────────────────────────────
// PAGE 1 — "En direct" : feed vertical des lives en cours
// ───────────────────────────────────────────────────────────────────────────
class _LivesFeed extends StatefulWidget {
  const _LivesFeed({this.onGoForYou});

  /// Ramène sur « Pour toi » depuis l'état vide.
  final VoidCallback? onGoForYou;

  @override
  State<_LivesFeed> createState() => _LivesFeedState();
}

class _LivesFeedState extends State<_LivesFeed> {
  final eventController = Get.find<EventController>();

  /// Vrai pendant la première séquence de requêtes (spinner fini, jamais de
  /// shimmer infini).
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Lives en cours, puis concerts à venir (affichés dans l'état vide) s'ils
  /// ne sont pas déjà en mémoire. Séquentiel : l'ApiResponse du contrôleur
  /// est partagé entre les requêtes.
  Future<void> _load() async {
    try {
      await eventController.getEventsByStatus(status: EventStatus.live);
      if (eventController.allEvents.value.data == null) {
        await eventController.getEventsByStatus(
          status: EventStatus.published,
          dateStatus: EventDateStatus.future,
        );
      }
    } catch (e) {
      myPrint('lives feed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<EventController>(
      builder: (controller) {
        final lives = controller.liveNowEvents.value.data;
        if (lives == null || lives.isEmpty) {
          // Spinner uniquement tant que la liste n'a JAMAIS été reçue et
          // qu'une requête est en cours ; sinon état vide chaleureux avec la
          // carte « À la une » et les concerts à venir — jamais d'écran noir.
          if (lives == null && (_loading || controller.isLoadingLiveNow)) {
            return const _FeedLoading();
          }
          return _FeedFallback(
            icon: Icons.sensors_off_rounded,
            titleKey: 'live_empty_t',
            subtitleKey: 'live_empty_s',
            onGoForYou: widget.onGoForYou,
          );
        }
        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: lives.length,
          itemBuilder: (context, index) =>
              _LivePreviewCard(event: lives[index]),
        );
      },
    );
  }
}

/// Surface vidéo d'un clip de feed (« Pour toi » / « Clips ») : le lecteur
/// dès qu'il est initialisé, avec la miniature Mux ([FeedPoster]) PAR-DESSUS
/// tant que sa première image n'est pas rendue (position encore à zéro).
/// Jamais d'écran noir entre deux clips ni au lancement. Se rafraîchit sur
/// chaque changement de valeur du lecteur (init, position), sans passer par
/// un rebuild de tout le feed.
class _ReelSurface extends StatelessWidget {
  const _ReelSurface({required this.controller, required this.posterUrl});

  final VideoPlayerController? controller;
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null) return FeedPoster(url: posterUrl);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) {
        final firstFrameShown =
            value.isInitialized && value.position > Duration.zero;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
            if (!firstFrameShown) FeedPoster(url: posterUrl),
          ],
        );
      },
    );
  }
}

/// Attente (finie) d'un feed : fond bleu nuit + spinner or.
class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: midnightPrimary,
      child: Center(child: CircularProgressIndicator(color: goldPrimary)),
    );
  }
}

/// État vide chaleureux d'un feed (« En direct » sans live, « Pour toi »
/// sans clip) : message + carte « À la une » (« Prochain grand live ») si
/// l'admin a mis un concert en avant + concerts à venir cliquables.
class _FeedFallback extends StatefulWidget {
  const _FeedFallback({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    this.onGoForYou,
  });

  final IconData icon;

  /// Clés de traduction du titre / sous-titre.
  final String titleKey;
  final String subtitleKey;

  /// Si non nul, bouton « Voir Pour toi ».
  final VoidCallback? onGoForYou;

  @override
  State<_FeedFallback> createState() => _FeedFallbackState();
}

class _FeedFallbackState extends State<_FeedFallback> {
  final eventController = Get.find<EventController>();
  FeaturedEvent? _featured = cachedFeaturedEvent;

  @override
  void initState() {
    super.initState();
    getFeaturedEvent().then((featured) {
      if (mounted) setState(() => _featured = featured);
    });
  }

  /// Concerts à venir (max 5), triés par date, sans le concert déjà affiché
  /// en « À la une ».
  List<Event> _upcoming() {
    final featuredId = _featured?.event.id;
    final list = (eventController.allEvents.value.data ?? const <Event>[])
        .where(
          (e) =>
              e.startDateTime != null &&
              (featuredId == null || e.id != featuredId),
        )
        .toList()
      ..sort((a, b) => a.startDateTime!.compareTo(b.startDateTime!));
    return list.take(5).toList();
  }

  Widget _goForYouButton(VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: goldSecondary, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_outline_rounded,
                color: goldPrimary, size: 18),
            const SizedBox(width: 8),
            Text(
              'live_go_for_you'.tr,
              style: const TextStyle(
                color: goldPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final onGoForYou = widget.onGoForYou;
    return Container(
      color: midnightPrimary,
      width: Get.width,
      height: Get.height,
      child: GetBuilder<EventController>(
        builder: (_) {
          final featured = _featured;
          final upcoming = _upcoming();
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, topInset + 80, 16, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Icon(
                    widget.icon,
                    color: whiteColor.withValues(alpha: 0.4),
                    size: 56,
                  ),
                ),
                height(0.02),
                Center(
                  child: Text(
                    widget.titleKey.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: whiteColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                height(0.01),
                Center(
                  child: Text(
                    widget.subtitleKey.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: whiteColor.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                if (onGoForYou != null) ...[
                  height(0.025),
                  Center(child: _goForYouButton(onGoForYou)),
                ],
                if (featured != null) ...[
                  height(0.04),
                  SectionHeader(title: 'live_next_big_live'.tr),
                  height(0.015),
                  FeaturedEventCard(featured: featured),
                ],
                if (upcoming.isNotEmpty) ...[
                  height(0.04),
                  SectionHeader(title: 'upcoming_events'.tr),
                  height(0.015),
                  for (final e in upcoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: UpcomingEventTile(event: e),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Carte live : apercu gratuit 60s (image + badge LIVE) puis gate opaque.
class _LivePreviewCard extends StatefulWidget {
  final Event event;
  const _LivePreviewCard({required this.event});

  @override
  State<_LivePreviewCard> createState() => _LivePreviewCardState();
}

class _LivePreviewCardState extends State<_LivePreviewCard>
    with SingleTickerProviderStateMixin {
  static const int previewSeconds = 60;
  Timer? _timer;
  int _remaining = previewSeconds;
  bool _gated = false;
  late final AnimationController _zoom;

  bool get _hasAccess {
    final owns = (widget.event.ticketBuyerIds ?? [])
        .contains(userModel.value.user?.id ?? 1);
    final price = double.tryParse(widget.event.ticketPrice ?? '') ?? 0;
    return owns || price <= 0;
  }

  /// Gate opaque : aperçu terminé ET toujours pas d'accès (après un achat,
  /// la liste est rechargée -> widget.event porte le billet -> gate levée).
  bool get _showGate => _gated && !_hasAccess;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    if (!_hasAccess) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _remaining = 0;
          _gated = true;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _zoom.dispose();
    super.dispose();
  }

  void _joinLive() => joinLive(widget.event);

  /// Fiche du concert ; au retour (achat éventuel), on recharge la liste des
  /// lives pour que la carte reflète le billet (avant, la liste n'était
  /// chargée qu'une fois au premier affichage).
  void _openDetail() {
    Get.to(() => FutureScreen(event: widget.event))?.then((_) {
      Get.find<EventController>().getEventsByStatus(status: EventStatus.live);
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Aperçu = image de couverture avec léger zoom (Ken Burns).
        ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.12).animate(
            CurvedAnimation(parent: _zoom, curve: Curves.easeInOut),
          ),
          child: ImageWidget(
            url: '${APIs.eventImageIP}/${e.coverImage}',
            fit: BoxFit.cover,
            // Couverture plein écran : décodée à 1080 px max (pas en pleine
            // résolution d'upload).
            memCacheWidth: 1080,
          ),
        ),
        // Dégradés pour lisibilité
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0x00000000), Color(0xCC000000)],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),

        // Badge LIVE + spectateurs (haut gauche)
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          left: 16,
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: liveRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: Colors.white, size: 7),
                    const SizedBox(width: 5),
                    Text(
                      'live_badge'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Infos bas + CTA
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: e.artist != null
                      ? () => Get.to(() => ArtistDetailScreen(artist: e.artist!))
                      : null,
                  child: Text(
                    '@${e.artist?.artistName?.capitalize ?? 'live_artist_name_fallback'.tr}',
                    style: const TextStyle(
                      color: whiteColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                height(0.008),
                Text(
                  e.name?.capitalize ?? 'live_event_fallback'.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: whiteColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                height(0.018),

                // Apercu gratuit (barre + compteur) — uniquement si gate actif
                if (!_hasAccess && !_gated) ...[
                  Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded,
                          color: goldPrimary, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'live_free_preview'.trParams({
                          'seconds': '$_remaining',
                        }),
                        style: const TextStyle(
                          color: ivory,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (previewSeconds - _remaining) / previewSeconds,
                      minHeight: 4,
                      backgroundColor: whiteColor.withValues(alpha: 0.2),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(goldPrimary),
                    ),
                  ),
                  height(0.018),
                ],

                MyButton(
                  label: _hasAccess
                      ? 'live_enter_live'.tr
                      : 'live_join_the_live'.tr,
                  image: 'assets/arrow.png',
                  imageColor: midnightPrimary,
                  labelColor: midnightPrimary,
                  onTap: _hasAccess ? _joinLive : _openDetail,
                ),
                // Espace pour la bottom nav
                height(0.06),
              ],
            ),
          ),
        ),

        // ── Overlay opaque (gate) quand l'aperçu est terminé
        IgnorePointer(
          ignoring: !_showGate,
          child: AnimatedOpacity(
            opacity: _showGate ? 1 : 0,
            duration: const Duration(milliseconds: 600),
            child: Container(
              color: midnightPrimary.withValues(alpha: 0.92),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: goldPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: goldPrimary, size: 34),
                  ),
                  height(0.025),
                  Text(
                    'live_preview_ended'.tr,
                    style: TextStyle(
                      color: whiteColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  height(0.012),
                  Text(
                    'live_preview_ended_desc'.trParams({
                      'artist': e.artist?.artistName?.capitalize ??
                          'live_artist_name_fallback'.tr,
                    }),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: whiteColor.withValues(alpha: 0.7),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  height(0.03),
                  MyButton(
                    label: 'live_buy_ticket'.tr,
                    image: 'assets/arrow.png',
                    imageColor: midnightPrimary,
                    labelColor: midnightPrimary,
                    onTap: _openDetail,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// PAGE 2 — "Clips" : feed vertical des shorts UGC (uploadés via Mux).
// Contrôleur vidéo indépendant pour ne pas interférer avec "Pour toi".
// ───────────────────────────────────────────────────────────────────────────
class _ClipsFeed extends StatefulWidget {
  final bool isActive;
  const _ClipsFeed({required this.isActive});

  @override
  State<_ClipsFeed> createState() => _ClipsFeedState();
}

class _ClipsFeedState extends State<_ClipsFeed> with WidgetsBindingObserver {
  final eventController = Get.find<EventController>();
  final PageController _pageController = PageController();

  // ── Lecteurs : au plus DEUX vivants ──
  //  - [_controller] : clip affiché (lu quand l'onglet est actif) ;
  //  - [_next]       : clip index + 1, initialisé SANS être lu (démarrage
  //                    instantané au swipe), promu courant au changement de
  //                    page. Le clip précédent est libéré à ce moment-là.
  // Avant : 1 seul lecteur, recréé (init réseau complète) à chaque swipe.
  VideoPlayerController? _controller;
  VideoPlayerController? _next;
  int _nextIndex = -1;
  int _index = 0;

  /// Position à appliquer au lecteur courant dès qu'il est prêt (reprise
  /// après un passage en arrière-plan).
  Duration? _pendingSeek;

  // ── Cycle de vie (arrière-plan) : mêmes règles que « Pour toi » ──
  bool _releasedInBackground = false;
  bool _wasPlaying = false;
  Duration _resumeAt = Duration.zero;

  /// Plein écran (ReplayPlayerScreen) ouvert par-dessus : le clip du feed
  /// reste en pause et n'est pas relancé au retour d'arrière-plan.
  bool _inFullscreen = false;

  List<String> get _ids => eventController.clipsFeedUrls;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive && _ids.isNotEmpty) _showClip(0);
  }

  @override
  void didUpdateWidget(covariant _ClipsFeed old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      if (_controller == null) {
        _showClip(_index);
      } else {
        _controller?.play();
      }
    } else if (!widget.isActive && old.isActive) {
      _controller?.pause();
    }
  }

  /// Nouveau lecteur HLS (URL Mux plafonnée à 720p), en boucle, init lancée
  /// tout de suite (jamais deux initialize() sur le même lecteur).
  VideoPlayerController _createPlayer(String url) {
    final c = VideoPlayerController.networkUrl(Uri.parse(Mux.mobileHls(url)));
    c.setLooping(true);
    unawaited(
      c.initialize().then((_) => _onInitialized(c)).catchError((Object e) {
        myPrint('clips feed: $e');
      }),
    );
    return c;
  }

  /// Fin d'initialize() : si ce lecteur est (devenu) le courant, on le lance ;
  /// s'il est encore le préchargé, il reste en pause jusqu'à sa promotion.
  void _onInitialized(VideoPlayerController c) {
    if (!mounted || c != _controller) return;
    _startCurrent(c);
  }

  /// Lance le lecteur courant (initialisé) : setLooping + position de reprise
  /// éventuelle + play si l'onglet est visible, puis rafraîchit la page.
  void _startCurrent(VideoPlayerController c) {
    final seek = _pendingSeek;
    _pendingSeek = null;
    c.setLooping(true);
    if (seek != null && seek > Duration.zero) c.seekTo(seek);
    if (widget.isActive && !_inFullscreen) c.play();
    if (mounted) setState(() {});
  }

  /// Affiche (et lit si l'onglet est actif) le clip [i] : réutilise le lecteur
  /// préchargé s'il correspond, sinon en crée un ; libère le précédent ; puis
  /// précharge [i] + 1. Aucun await : rien ne bloque l'UI.
  void _showClip(int i, {Duration? startAt}) {
    final ids = _ids;
    if (i < 0 || i >= ids.length) return;
    _index = i;
    _pendingSeek = startAt;

    final previous = _controller;
    _controller = null;
    previous?.dispose();

    final VideoPlayerController c;
    final preloaded = _next;
    if (preloaded != null && _nextIndex == i && !preloaded.value.hasError) {
      c = preloaded;
      _next = null;
      _nextIndex = -1;
    } else {
      _next?.dispose();
      _next = null;
      _nextIndex = -1;
      c = _createPlayer(ids[i]);
    }
    _controller = c;
    // Déjà prêt (préchargé) : lecture immédiate ; sinon _onInitialized suivra.
    if (c.value.isInitialized) _startCurrent(c);
    _preload(i + 1);
    if (mounted) setState(() {});
  }

  /// Précharge le clip [i] (initialisé, jamais lu tant qu'il n'est pas promu).
  void _preload(int i) {
    final ids = _ids;
    if (i < 0 || i >= ids.length) {
      _next?.dispose();
      _next = null;
      _nextIndex = -1;
      return;
    }
    if (_next != null && _nextIndex == i) return;
    _next?.dispose();
    _next = _createPlayer(ids[i]);
    _nextIndex = i;
  }

  /// Libère les deux lecteurs (sortie de l'écran, arrière-plan).
  void _releaseAll() {
    _controller?.dispose();
    _controller = null;
    _next?.dispose();
    _next = null;
    _nextIndex = -1;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.inactive) {
      if (c != null && c.value.isInitialized) {
        _wasPlaying = _wasPlaying || c.value.isPlaying;
        c.pause();
      }
    } else if (state == AppLifecycleState.paused) {
      if (c == null && _next == null) return;
      if (c != null && c.value.isInitialized) {
        _wasPlaying = _wasPlaying || c.value.isPlaying;
        _resumeAt = c.value.position;
      }
      _releaseAll();
      _releasedInBackground = true;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      if (_releasedInBackground) {
        _releasedInBackground = false;
        if (widget.isActive && !_inFullscreen) {
          _showClip(_index, startAt: _resumeAt);
        }
        _resumeAt = Duration.zero;
      } else if (_wasPlaying &&
          widget.isActive &&
          !_inFullscreen &&
          c != null &&
          c.value.isInitialized) {
        c.play();
      }
      _wasPlaying = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releaseAll();
    _pageController.dispose();
    super.dispose();
  }

  /// Tap sur un clip (paysage) → plein écran paysage (façon YouTube).
  Future<void> _openFullscreen(int index) async {
    final ids = _ids;
    if (index >= ids.length) return;
    _controller?.pause();
    _inFullscreen = true;
    await Get.to(() => ReplayPlayerScreen(
          url: ids[index],
          playlist: ids,
          startIndex: index,
          autoAdvance: true,
          forceLandscape: true,
        ));
    _inFullscreen = false;
    if (!mounted || !widget.isActive) return;
    // Le lecteur a pu être libéré pendant un passage en arrière-plan.
    if (_controller == null) {
      _showClip(_index);
    } else {
      _controller?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    if (ids.isEmpty) return const _NoClipsState();

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: ids.length,
          onPageChanged: _showClip,
          itemBuilder: (context, index) {
            // Le lecteur courant n'est rattaché qu'à SA page : la page
            // voisine (visible pendant le swipe) montre son propre poster.
            final c = index == _index ? _controller : null;
            final ready = c != null && c.value.isInitialized;
            return GestureDetector(
              onTap: () => _openFullscreen(index),
              child: Container(
                width: Get.width,
                height: Get.height,
                color: blackColor,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _ReelSurface(
                      controller: c,
                      posterUrl: index < ids.length ? ids[index] : null,
                    ),
                    // Indice "plein écran" en bas à droite du clip.
                    if (ready)
                      Positioned(
                        right: 14,
                        bottom: 90,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.fullscreen,
                              color: Colors.white, size: 24),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // Libellé "VYBZZZ Clips"
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          left: 16,
          child: Row(
            children: [
              const Text(
                'VybzzZ',
                style: TextStyle(
                  color: whiteColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Clips',
                style: TextStyle(
                  color: goldPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Bouton "+" créer un short
        Positioned(
          top: MediaQuery.of(context).padding.top + 50,
          right: 12,
          child: GestureDetector(
            onTap: () => Get.to(() => const CreateShortScreen()),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: goldPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: midnightPrimary,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// État vide de l'onglet Clips : invite à ajouter un clip.
class _NoClipsState extends StatelessWidget {
  const _NoClipsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: midnightPrimary,
      width: Get.width,
      height: Get.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_collection_outlined,
              color: whiteColor.withValues(alpha: 0.4), size: 56),
          height(0.02),
          Text(
            'live_no_clips'.tr,
            style: TextStyle(
              color: whiteColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          height(0.01),
          Text(
            'clip_be_first'.tr,
            style: TextStyle(
              color: whiteColor.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          height(0.03),
          GestureDetector(
            onTap: () => Get.to(() => const CreateShortScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: goldPrimary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: midnightPrimary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'clip_create_title'.tr,
                    style: const TextStyle(
                      color: midnightPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
