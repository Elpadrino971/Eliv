import 'dart:async';
import 'dart:convert';

import 'package:artist/Global/api.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/services/api_services.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// ────────────────────────────────────────────────────────────────────────
/// ARTISTES INVITÉS (partage des revenus).
///
///   GET /api/artists/search?q=texte      -> [{ id, artist_name, full_name,
///                                            profile_image }]
///   GET /api/events/:id/guests           -> { guests[], remaining_pct }
///   PUT /api/events/:id/guests  guests=JSON -> même réponse (422 si Σ > 100)
///
/// Trois briques :
///   • [EventGuestsSheet]     : bottom sheet de recherche, renvoie l'invité
///                              choisi (mode création ET édition).
///   • [GuestSharesEditor]    : liste photo / nom / « % de ta part » /
///                              supprimer + « Il te reste X % ». Utilisé dans
///                              le formulaire de création (dans son Form) et
///                              dans le sheet d'édition.
///   • [EventGuestsEditSheet] : « Invités & partage » depuis la fiche concert
///                              artiste (GET puis PUT).
/// ────────────────────────────────────────────────────────────────────────

/// Σ des parts saisies.
int guestSharesTotal(List<EventGuest> guests) =>
    guests.fold<int>(0, (sum, g) => sum + g.sharePct);

/// URL de la photo d'un invité : chemin absolu conservé, nom de fichier
/// préfixé par le dossier des profils, vide -> avatar par défaut.
String guestImageUrl(String? image) {
  final img = (image ?? '').trim();
  if (img.isEmpty) return '${APIs.profileIP}/default.png';
  if (img.contains('://')) return img;
  return '${APIs.profileIP}/$img';
}

BoxDecoration _sheetDecoration() => BoxDecoration(
  color: Get.isDarkMode ? midnightSecondary : whiteColor,
  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
  // Bordure uniforme obligatoire avec un borderRadius (assertion Flutter).
  border: Border.all(color: goldSecondary.withValues(alpha: 0.35)),
);

Widget _sheetHandle() => Center(
  child: Container(
    width: 42,
    height: 4,
    margin: const EdgeInsets.only(top: 10, bottom: 12),
    decoration: BoxDecoration(
      color: textMuted.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(4),
    ),
  ),
);

Widget _sheetTitle(String text) => Text(
  text,
  style: TextStyle(
    fontFamily: AppFonts.ui,
    color: Get.isDarkMode ? ivory : blackColor,
    fontWeight: FontWeight.bold,
    fontSize: 16,
  ),
);

Widget _guestAvatar(EventGuest guest, {double size = 40}) => ClipOval(
  child: ImageWidget(
    url: guestImageUrl(guest.profileImage),
    width: size,
    height: size,
  ),
);

// ═════════════════════════════════════════════════════════════════════════
// 1. Recherche d'un artiste (bottom sheet)
// ═════════════════════════════════════════════════════════════════════════

class EventGuestsSheet extends StatefulWidget {
  const EventGuestsSheet({super.key, this.excludeIds = const <int>{}});

  /// Ids déjà invités (masqués des résultats). L'artiste courant est
  /// toujours exclu.
  final Set<int> excludeIds;

  /// Ouvre le sheet et renvoie l'artiste choisi (null si fermé sans choix).
  static Future<EventGuest?> pick(
    BuildContext context, {
    Set<int> excludeIds = const <int>{},
  }) {
    return showModalBottomSheet<EventGuest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventGuestsSheet(excludeIds: excludeIds),
    );
  }

  @override
  State<EventGuestsSheet> createState() => _EventGuestsSheetState();
}

class _EventGuestsSheetState extends State<EventGuestsSheet> {
  static const int _minChars = 2;
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  final _searchController = TextEditingController();
  final _response = ApiResponse();
  Timer? _debounce;
  int _seq = 0;
  bool _loading = false;
  String _query = '';
  List<EventGuest> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String raw) {
    final q = raw.trim();
    _debounce?.cancel();
    _seq++;
    if (q.length < _minChars) {
      setState(() {
        _query = q;
        _loading = false;
        _results = [];
      });
      return;
    }
    setState(() {
      _query = q;
      _loading = true;
    });
    final int seq = _seq;
    _debounce = Timer(_debounceDelay, () => _search(q, seq));
  }

  Future<void> _search(String q, int seq) async {
    List<EventGuest> found = [];
    try {
      _response.typeSetter = 'get';
      _response.urlSetter = APIs.artistsSearchAPI(q);
      final dynamic value = await _response.hitAPI();
      if (value is String && value.split(' ').first != 'error') {
        final decoded = jsonDecode(value);
        final data = decoded is Map ? decoded['data'] : null;
        final List rawList = data is List ? data : const [];
        final int? selfId = userModel.value.user?.id;
        found = rawList
            .whereType<Map>()
            .map((Map x) => EventGuest.fromJson(x))
            .where(
              (g) =>
                  g.userId > 0 &&
                  g.userId != selfId &&
                  !widget.excludeIds.contains(g.userId),
            )
            .toList();
      } else {
        // Recherche silencieuse : une erreur = liste vide.
        myPrint('artists/search: $value');
      }
    } catch (e) {
      myPrint('artists/search: exception -> $e');
    }
    if (!mounted || seq != _seq) return;
    setState(() {
      _results = found;
      _loading = false;
    });
  }

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          color: textMuted,
          fontSize: 14,
        ),
      ),
    ),
  );

  Widget _resultTile(EventGuest guest) {
    final full = (guest.fullName ?? '').trim();
    final showFull = full.isNotEmpty && full != guest.displayName;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).pop(guest),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Get.isDarkMode ? cardDeep : const Color(0xffF3F3F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: greyColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            _guestAvatar(guest),
            width(0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guest.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      color: Get.isDarkMode ? ivory : blackColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (showFull)
                    Text(
                      full,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline_rounded, color: goldPrimary),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_query.length < _minChars) return _hint('guest_search_min'.tr);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator(color: goldPrimary)),
      );
    }
    if (_results.isEmpty) return _hint('guest_search_empty'.tr);
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _resultTile(_results[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: Get.height * 0.75,
        decoration: _sheetDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            _sheetTitle('guest_pick_title'.tr),
            height(0.005),
            MyTextField(
              hintText: 'guest_search_hint'.tr,
              controller: _searchController,
              autoFocus: true,
              textInputAction: TextInputAction.search,
              leading: const Icon(
                Icons.search_rounded,
                color: goldSecondary,
                size: 20,
              ),
              onChanged: _onQueryChanged,
            ),
            height(0.005),
            Expanded(child: _body()),
            height(0.02),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// 2. Éditeur des parts (liste + « Il te reste X % » + bouton d'ajout)
// ═════════════════════════════════════════════════════════════════════════

class GuestSharesEditor extends StatefulWidget {
  const GuestSharesEditor({
    super.key,
    required this.guests,
    required this.onChanged,
    required this.onAdd,
  });

  final List<EventGuest> guests;

  /// Nouvelle liste après saisie d'un % ou suppression.
  final ValueChanged<List<EventGuest>> onChanged;

  /// « + Ajouter un invité ».
  final VoidCallback onAdd;

  @override
  State<GuestSharesEditor> createState() => _GuestSharesEditorState();
}

class _GuestSharesEditorState extends State<GuestSharesEditor> {
  /// Un contrôleur par invité (clé = user_id) : conservé entre rebuilds pour
  /// ne pas perdre le texte en cours de saisie.
  final Map<int, TextEditingController> _controllers = {};

  TextEditingController _controllerFor(EventGuest guest) {
    return _controllers.putIfAbsent(
      guest.userId,
      () => TextEditingController(
        text: guest.sharePct > 0 ? '${guest.sharePct}' : '',
      ),
    );
  }

  @override
  void didUpdateWidget(covariant GuestSharesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Libère les contrôleurs des invités retirés, après la frame : le
    // TextFormField correspondant est encore dans l'arbre pendant ce build.
    final ids = widget.guests.map((g) => g.userId).toSet();
    final orphans = _controllers.keys.where((id) => !ids.contains(id)).toList();
    if (orphans.isEmpty) return;
    final removed = [for (final id in orphans) _controllers.remove(id)];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in removed) {
        c?.dispose();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setPct(EventGuest guest, String text) {
    final pct = int.tryParse(text.trim()) ?? 0;
    final updated = widget.guests
        .map((g) => g.userId == guest.userId ? g.copyWith(sharePct: pct) : g)
        .toList();
    widget.onChanged(updated);
  }

  void _remove(EventGuest guest) {
    widget.onChanged(
      widget.guests.where((g) => g.userId != guest.userId).toList(),
    );
  }

  Widget _guestRow(EventGuest guest) {
    final textColor = Get.isDarkMode ? ivory : blackColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Get.isDarkMode ? cardDeep : const Color(0xffF3F3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: greyColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _guestAvatar(guest, size: 38),
          width(0.025),
          Expanded(
            child: Text(
              guest.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.body,
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
          width(0.02),
          SizedBox(
            width: 96,
            child: TextFormField(
              controller: _controllerFor(guest),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: TextStyle(
                fontFamily: AppFonts.ui,
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              cursorColor: goldPrimary,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Get.isDarkMode ? midnightSecondary : whiteColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                labelText: 'guest_share_label'.tr,
                labelStyle: const TextStyle(
                  fontFamily: AppFonts.body,
                  color: textMuted,
                  fontSize: 10,
                ),
                suffixText: '%',
                suffixStyle: const TextStyle(color: goldPrimary, fontSize: 13),
                errorStyle: const TextStyle(fontSize: 9, height: 0.9),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: goldSecondary.withValues(alpha: 0.25),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: goldPrimary, width: 1.4),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: liveRed),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: liveRed, width: 1.4),
                ),
              ),
              validator: (value) {
                final pct = int.tryParse((value ?? '').trim());
                if (pct == null || pct < 1 || pct > 100) {
                  return 'guest_share_invalid'.tr;
                }
                return null;
              },
              onChanged: (value) => _setPct(guest, value),
            ),
          ),
          IconButton(
            tooltip: 'art_delete'.tr,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, color: textMuted, size: 20),
            onPressed: () => _remove(guest),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = guestSharesTotal(widget.guests);
    final remaining = 100 - total;
    final over = total > 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.guests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'guest_empty'.tr,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                color: textMuted,
                fontSize: 12.5,
              ),
            ),
          )
        else ...[
          for (final g in widget.guests) _guestRow(g),
          Text(
            over
                ? 'guest_over'.tr
                : 'guest_remaining'.trParams({'pct': '$remaining'}),
            style: TextStyle(
              fontFamily: AppFonts.ui,
              color: over ? liveRed : goldPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'guest_hint'.tr,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              color: textMuted,
              fontSize: 11.5,
            ),
          ),
        ],
        const SizedBox(height: 8),
        MyButton(
          label: 'guest_add'.tr,
          onTap: widget.onAdd,
          buttonColor: Colors.transparent,
          borderColor: goldSecondary,
          labelColor: goldPrimary,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// 3. Édition depuis la fiche concert (GET puis PUT)
// ═════════════════════════════════════════════════════════════════════════

class EventGuestsEditSheet extends StatefulWidget {
  const EventGuestsEditSheet({super.key, required this.eventId});

  final String eventId;

  static Future<void> show(BuildContext context, {required String eventId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventGuestsEditSheet(eventId: eventId),
    );
  }

  @override
  State<EventGuestsEditSheet> createState() => _EventGuestsEditSheetState();
}

class _EventGuestsEditSheetState extends State<EventGuestsEditSheet> {
  // Deux ApiResponse : le GET et le PUT ne s'écrasent pas l'URL/le type.
  final _loadResponse = ApiResponse();
  final _saveResponse = ApiResponse();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  List<EventGuest> _guests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Lit `data.guests` d'une réponse GET/PUT ; null si le format est inattendu.
  List<EventGuest>? _parseGuests(String value) {
    try {
      final decoded = jsonDecode(value);
      final data = decoded is Map ? decoded['data'] : null;
      if (data is! Map) return null;
      final raw = data['guests'];
      final List rawList = raw is List ? raw : const [];
      return rawList
          .whereType<Map>()
          .map((Map x) => EventGuest.fromJson(x))
          .toList();
    } catch (e) {
      myPrint('events/guests: $e');
      return null;
    }
  }

  Future<void> _load() async {
    _loadResponse.typeSetter = 'get';
    _loadResponse.urlSetter = APIs.eventGuestsAPI(widget.eventId);
    final dynamic value = await _loadResponse.hitAPI();
    if (!mounted) return;
    if (value is String && value.split(' ').first != 'error') {
      final parsed = _parseGuests(value);
      if (parsed != null) _guests = parsed;
    } else {
      parseError('$value');
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? true)) return;
    if (guestSharesTotal(_guests) > 100) {
      myWarningDialog(subtitle: 'guest_over'.tr);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    _saveResponse.typeSetter = 'put';
    _saveResponse.urlSetter = APIs.eventGuestsAPI(widget.eventId);
    _saveResponse.bodySetter = {
      'guests': jsonEncode(_guests.map((g) => g.toShareJson()).toList()),
    };
    final dynamic value = await _saveResponse.hitAPI();
    if (!mounted) return;
    setState(() => _saving = false);
    if (value is String && value.split(' ').first != 'error') {
      Get.snackbar(
        'guest_manage'.tr,
        'guest_saved'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: cardDeep,
        colorText: ivory,
        margin: const EdgeInsets.all(14),
        borderRadius: 14,
      );
      Navigator.of(context).pop();
    } else {
      // 422 (Σ > 100, artiste inconnu…) : message serveur affiché tel quel.
      parseError('$value');
    }
  }

  Future<void> _add() async {
    final picked = await EventGuestsSheet.pick(
      context,
      excludeIds: _guests.map((g) => g.userId).toSet(),
    );
    if (picked == null || !mounted) return;
    // Part par défaut : 10 %, ou ce qu'il reste si moins.
    final int remaining = (100 - guestSharesTotal(_guests)).clamp(0, 100).toInt();
    setState(() {
      _guests = [
        ..._guests,
        picked.copyWith(sharePct: remaining >= 10 ? 10 : remaining),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final over = guestSharesTotal(_guests) > 100;
    final disabled = _saving || over || _loading;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: Get.height * 0.85,
        decoration: _sheetDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            _sheetTitle('guest_manage'.tr),
            height(0.01),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: goldPrimary),
                    )
                  : SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: GuestSharesEditor(
                          guests: _guests,
                          onChanged: (list) => setState(() => _guests = list),
                          onAdd: _add,
                        ),
                      ),
                    ),
            ),
            height(0.01),
            Opacity(
              opacity: disabled ? 0.55 : 1.0,
              child: MyButton(
                label: _saving ? 'common_loading'.tr : 'guest_save'.tr,
                onTap: () {
                  if (!disabled) _save();
                },
              ),
            ),
            height(0.02),
          ],
        ),
      ),
    );
  }
}
