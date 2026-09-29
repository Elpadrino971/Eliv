import 'dart:convert';
import 'dart:io';

import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/app_date.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/artist_bottom_bar/screen/Events/event_guests_sheet.dart';
import 'package:artist/widgets/revenue_estimate_card.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ArtistCreateEvent extends StatefulWidget {
  const ArtistCreateEvent({super.key});

  @override
  State<ArtistCreateEvent> createState() => _ArtistCreateEventState();
}

class _ArtistCreateEventState extends State<ArtistCreateEvent> {
  final artistController = Get.find<ArtistController>();

  final titleController = TextEditingController();
  final genreController = TextEditingController();
  final descriptionController = TextEditingController();
  final startDateController = TextEditingController();
  final startTimeController = TextEditingController();
  final endDateController = TextEditingController();
  final endTimeController = TextEditingController();
  final standardController = TextEditingController();
  final vipController = TextEditingController();
  String? selectedGenre;

  // Paliers de prix des billets — chaque prix correspond à un produit IAP
  // (ticket_19, ticket_29, …) créé dans les stores. L'artiste choisit un palier.
  // 129.99/149.99 retirés : paliers à prix élevé qui avaient causé un souci de
  // soumission (Apple demande une justification supplémentaire au-delà d'un
  // certain prix, Guideline 3.1.1). Les produits IAP restent créés dans
  // App Store Connect/Play Console, juste plus proposés dans ce sélecteur.
  final List<String> _ticketTiers = [
    // Paliers d'accès (impulsion / accessibilité). Chaque prix a un produit IAP
    // consommable dédié côté App Store / RevenueCat : id = ticket_<partie entière>
    // (2.99 -> ticket_2, 4.99 -> ticket_4, … 99.99 -> ticket_99).
    '2.99', '4.99', '6.99', '9.99', '14.99',
    '19.99', '29.99', '39.99', '49.99', '59.99',
    '79.99', '99.99',
  ];
  String? selectedPrice;

  /// Prix numérique du palier choisi (0 = « Gratuit » ou rien de choisi).
  double get _selectedPriceValue {
    final raw = selectedPrice;
    if (raw == null || raw == 'common_free'.tr) return 0;
    return double.tryParse(raw.replaceAll(' €', '').trim()) ?? 0;
  }

  /// Artistes invités (partage des revenus) choisis dans le formulaire.
  List<EventGuest> _guests = [];

  bool get _guestsOver => guestSharesTotal(_guests) > 100;

  Future<void> _addGuest() async {
    final picked = await EventGuestsSheet.pick(
      context,
      excludeIds: _guests.map((g) => g.userId).toSet(),
    );
    if (picked == null || !mounted) return;
    // Part par défaut : 10 %, ou ce qu'il reste si moins.
    final int remaining =
        (100 - guestSharesTotal(_guests)).clamp(0, 100).toInt();
    setState(() {
      _guests = [
        ..._guests,
        picked.copyWith(sharePct: remaining >= 10 ? 10 : remaining),
      ];
    });
  }

  bool liveValue = true;

  // Replay : activé par défaut, durée par défaut 60j (plafond = fenêtre de hold
  // Apple). L'artiste peut désactiver ou raccourcir.
  bool replayEnabled = true;
  int replayDurationDays = 60;

  final formKey = GlobalKey<FormState>();

  File? coverImage;
  XFile? visualVideo;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        coverImage = File(image.path);
      });
    }
  }

  // Limites du visuel vidéo : bornent l'upload pour éviter le "chargement dans
  // le vide" (une vidéo de plusieurs centaines de Mo s'envoie très lentement en
  // mobile). Durée max 60 s + garde-fou sur la TAILLE réelle en octets, car
  // maxDuration n'est pas toujours respecté par la galerie iOS. Ajustables.
  static const int _maxVisualDurationSec = 60;
  static const int _maxVisualMb = 100;

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: _maxVisualDurationSec),
    );
    if (video == null) return;
    final int bytes = await video.length();
    if (bytes > _maxVisualMb * 1024 * 1024) {
      final int mb = (bytes / (1024 * 1024)).round();
      Get.snackbar(
        'art_error'.tr,
        'Vidéo trop lourde ($mb Mo, max $_maxVisualMb Mo). '
        'Choisis un clip plus court ou de moindre qualité.',
      );
      return;
    }
    setState(() {
      visualVideo = video;
    });
  }

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      final now = DateTime.now();
      final dt = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      setState(() {
        controller.text = DateFormat('HH:mm:ss').format(dt);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'ev_create_event'.tr),

      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: myPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ev_create'.tr,
                  style: TextStyle(
                    color: ivory,

                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),

                Text(
                  'ev_new_performance'.tr,
                  style: TextStyle(
                    color: Color(0xff737373),

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                height(0.02),

                Text(
                  'art_event_details'.tr,
                  style: TextStyle(
                    color: ivory,

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                height(0.01),
                Text(
                  'art_title_req'.tr,
                  style: TextStyle(
                    color: Color(0xff737373),

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                MyTextField(
                  hintText: 'art_hint_event_title'.tr,
                  controller: titleController,
                  validation: (value) {
                    if (value == null || value.isEmpty) {
                      return 'art_val_title'.tr;
                    }
                    return null;
                  },
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'art_genre_req'.tr,
                      style: TextStyle(
                        color: Color(0xff737373),

                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    Obx(() {
                      final genre = artistController.genres.value.genre ?? [];
                      return MyDropDown(
                        dropdownvalue: selectedGenre,
                        hintText: 'ev_select_genre'.tr,
                        items: genre.map((e) => e.genre ?? '').toList(),
                        onChanged: (value) {
                          selectedGenre = value;
                        },
                        validation: (value) {
                          if (value == null) {
                            return 'art_val_genre'.tr;
                          }
                          return null;
                        },
                      );
                    }),
                  ],
                ),

                height(0.01),
                Text(
                  'art_description_req'.tr,
                  style: TextStyle(
                    color: Color(0xff737373),

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                MyTextField(
                  hintText: 'chat_share_show'.tr,
                  controller: descriptionController,
                  maxLines: 4,
                  validation: (value) {
                    if (value == null || value.isEmpty) {
                      return 'art_val_description'.tr;
                    }
                    return null;
                  },
                ),

                height(0.01),
                Text(
                  'art_cover_image_req'.tr,
                  style: TextStyle(
                    color: ivory,

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                height(0.01),

                GestureDetector(
                  onTap: _pickImage,
                  child: MyContainer(
                    padding: coverImage != null
                        ? EdgeInsets.all(0)
                        : EdgeInsets.only(
                            top: 30,
                            bottom: 30,
                            left: 15,
                            right: 15,
                          ),

                    widget: coverImage != null
                        ? Image.file(
                            coverImage!,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          )
                        : Column(
                            children: [
                              Image.asset('assets/upload4.png', width: 20),

                              Text(
                                'art_upload_cover'.tr,
                                style: TextStyle(
                                  color: Color(0xffA1A1A1),

                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  ),
                ),

                height(0.01),
                Text(
                  'art_visuals_req'.tr,
                  style: TextStyle(
                    color: ivory,

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                height(0.01),

                GestureDetector(
                  onTap: _pickVideo,
                  child: MyContainer(
                    padding: EdgeInsets.only(
                      top: 30,
                      bottom: 30,
                      left: 15,
                      right: 15,
                    ),

                    widget: Column(
                      children: [
                        visualVideo != null
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : Image.asset('assets/upload4.png', width: 20),

                        Text(
                          visualVideo != null
                              ? visualVideo!.name
                              : 'art_upload_visual'.tr,
                          style: TextStyle(
                            color: Color(0xffA1A1A1),

                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

                height(0.02),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'art_start_date_req'.tr,
                          style: TextStyle(
                            color: Color(0xff737373),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(
                          width: Get.width * 0.44,
                          child: MyTextField(
                            hintText: 'yyyy-mm-dd',
                            controller: startDateController,
                            readOnly: true,
                            leading: Image.asset(
                              'assets/date_icon2.png',
                              color: Color(0xffD4D4D4),
                            ),
                            onTap: () =>
                                _pickDate(context, startDateController),
                            validation: (value) {
                              if (value == null || value.isEmpty) {
                                return 'art_required'.tr;
                              }
                              return null;
                            },
                            textColor: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'art_start_time_req'.tr,
                          style: TextStyle(
                            color: Color(0xff737373),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(
                          width: Get.width * 0.44,
                          child: MyTextField(
                            hintText: 'hh:mm:ss',
                            controller: startTimeController,
                            readOnly: true,
                            leading: Image.asset(
                              'assets/clock.png',
                              width: 20,
                              color: Color(0xff737373),
                            ),
                            onTap: () =>
                                _pickTime(context, startTimeController),
                            validation: (value) {
                              if (value == null || value.isEmpty) {
                                return 'art_required'.tr;
                              }
                              return null;
                            },
                            textColor: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                height(0.01),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'art_end_date_req'.tr,
                          style: TextStyle(
                            color: Color(0xff737373),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(
                          width: Get.width * 0.44,
                          child: MyTextField(
                            hintText: 'yyyy-mm-dd',
                            controller: endDateController,
                            readOnly: true,
                            leading: Image.asset(
                              'assets/date_icon2.png',
                              color: Color(0xffD4D4D4),
                            ),
                            onTap: () => _pickDate(context, endDateController),
                            // Fin OPTIONNELLE : si vide -> début + 4h (cf. submit).
                            validation: (value) => null,
                            textColor: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'art_end_time_req'.tr,
                          style: TextStyle(
                            color: Color(0xff737373),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(
                          width: Get.width * 0.44,
                          child: MyTextField(
                            hintText: 'hh:mm:ss',
                            controller: endTimeController,
                            readOnly: true,
                            leading: Image.asset(
                              'assets/clock.png',
                              width: 20,
                              color: Color(0xff737373),
                            ),
                            onTap: () => _pickTime(context, endTimeController),
                            validation: (value) => null,
                            textColor: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                height(0.01),

                Text(
                  'art_standard_price_req'.tr,
                  style: TextStyle(
                    color: Color(0xff737373),

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                MyDropDown(
                  dropdownvalue: selectedPrice,
                  hintText: 'hint_price'.tr,
                  // « Gratuit » en tête : concert à 0 €, aucun achat store,
                  // le fan rejoint directement (voir check_out_screen).
                  items: [
                    'common_free'.tr,
                    ..._ticketTiers.map((t) => '$t €'),
                  ],
                  onChanged: (value) {
                    // On garde la valeur affichée ("49.99 €") pour qu'elle
                    // corresponde à un item du dropdown ; le " €" est retiré
                    // seulement à l'envoi.
                    setState(() => selectedPrice = value);
                  },
                  validation: (value) {
                    if (value == null) {
                      return 'art_val_ticket_price'.tr;
                    }
                    return null;
                  },
                ),

                // « Ce que tu gagnes » : décomposition du prix choisi (frais
                // store, net, part artiste, VybzzZ, invités, projections).
                // Masqué tant qu'aucun palier n'est choisi ; « Gratuit »
                // affiche le message concert gratuit.
                if (selectedPrice != null) ...[
                  height(0.008),
                  RevenueEstimateCard(
                    price: _selectedPriceValue,
                    guests: [
                      for (final g in _guests)
                        GuestShare(name: g.displayName, sharePct: g.sharePct),
                    ],
                  ),
                ],

                height(0.015),

                // ── Artistes invités (partage des revenus) ────────────────
                Text(
                  'guest_section_title'.tr,
                  style: TextStyle(
                    color: Get.isDarkMode ? whiteColor : blackColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                height(0.005),
                GuestSharesEditor(
                  guests: _guests,
                  onChanged: (list) => setState(() => _guests = list),
                  onAdd: _addGuest,
                ),

                height(0.015),

                Text(
                  'common_settings'.tr,
                  style: TextStyle(
                    color: Get.isDarkMode ? whiteColor : blackColor,

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                Row(
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/setting.png',
                          width: 20,
                          height: 20,
                          color: Color(0xffA1A1A1),
                        ),
                        width(0.02),

                        Text(
                          'live_chat'.tr,
                          style: TextStyle(
                            color: Get.isDarkMode ? whiteColor : blackColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        height(0.01),
                      ],
                    ),
                    Spacer(),
                    Switch(
                      value: liveValue,
                      onChanged: (value) {
                        setState(() {
                          liveValue = value;
                        });
                      },

                      inactiveThumbColor: whiteColor,
                      inactiveTrackColor: greyColor,
                      activeTrackColor: mainThemeColor,
                      activeThumbColor: whiteColor,
                    ),
                  ],
                ),

                // ── Replay (rejouable après le live) ──────────────────────
                Row(
                  children: [
                    Image.asset(
                      'assets/setting.png',
                      width: 20,
                      height: 20,
                      color: Color(0xffA1A1A1),
                    ),
                    width(0.02),
                    Text(
                      'replay_enable'.tr,
                      style: TextStyle(
                        color: Get.isDarkMode ? whiteColor : blackColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Spacer(),
                    Switch(
                      value: replayEnabled,
                      onChanged: (value) {
                        setState(() {
                          replayEnabled = value;
                        });
                      },
                      inactiveThumbColor: whiteColor,
                      inactiveTrackColor: greyColor,
                      activeTrackColor: mainThemeColor,
                      activeThumbColor: whiteColor,
                    ),
                  ],
                ),

                // Durée du replay (visible seulement si activé)
                if (replayEnabled) ...[
                  height(0.005),
                  Text(
                    'replay_duration_label'.trParams({
                      'days': '$replayDurationDays',
                    }),
                    style: TextStyle(
                      color: Color(0xff737373),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [7, 14, 30, 60].map((d) {
                      final selected = replayDurationDays == d;
                      return ChoiceChip(
                        label: Text('$d j'),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => replayDurationDays = d);
                        },
                        labelStyle: TextStyle(
                          color: selected ? whiteColor : Color(0xffA1A1A1),
                          fontWeight: FontWeight.bold,
                        ),
                        selectedColor: mainThemeColor,
                        backgroundColor: Get.isDarkMode
                            ? midnightSecondary
                            : Color(0xffEDEDED),
                      );
                    }).toList(),
                  ),
                ],

                height(0.02),
                // Publier désactivé tant que les parts des invités dépassent
                // 100 % (message rouge dans la section invités).
                Opacity(
                  opacity: _guestsOver ? 0.55 : 1.0,
                  child: MyButton(
                    label: 'ev_publish'.tr,
                    onTap: () {
                      if (_guestsOver) return;
                      if (formKey.currentState!.validate()) {
                        // Image de couverture et vidéo teaser désormais
                        // OPTIONNELLES : le backend les accepte vides. On ne
                        // bloque plus la création d'un concert pour ça (grosse
                        // friction retirée). Elles s'ajoutent quand l'artiste veut.

                        // Call API logic
                        // firstOrNull : un genre non trouvé ne doit pas
                        // planter la création (firstWhere sans orElse lançait).
                        final selectedGenreId = artistController
                            .genres
                            .value
                            .genre
                            ?.where((e) => e.genre == selectedGenre)
                            .firstOrNull
                            ?.id;

                        // Fin OPTIONNELLE : si vide -> début + 4h (fenêtre large
                        // => le bouton "Passer en direct" reste actif, et le
                        // replay a une référence de fin).
                        final startLocal = DateTime.tryParse(
                            '${startDateController.text} ${startTimeController.text}');
                        final String endIso = (endDateController.text.isEmpty ||
                                endTimeController.text.isEmpty)
                            ? (startLocal != null
                                ? '${startLocal.add(const Duration(hours: 4)).toUtc().toIso8601String().split('.').first}Z'
                                : AppDate.localPartsToUtcIso(
                                    startDateController.text, startTimeController.text))
                            : AppDate.localPartsToUtcIso(
                                endDateController.text, endTimeController.text);

                        artistController.createEvent(
                          name: titleController.text,
                          description: descriptionController.text,
                          // Envoye en UTC (avec 'Z') pour que chaque spectateur
                          // voie l'heure dans son propre fuseau.
                          startDateTime: AppDate.localPartsToUtcIso(
                            startDateController.text,
                            startTimeController.text,
                          ),
                          endDateTime: endIso,
                          ticketPrice: selectedPrice == 'common_free'.tr
                              ? '0'
                              : (selectedPrice ?? '0').replaceAll(' €', ''),
                          genreId: selectedGenreId?.toString() ?? '',
                          hasLiveChat: liveValue ? '1' : '0',
                          replayEnabled: replayEnabled ? '1' : '0',
                          replayDurationDays: '$replayDurationDays',
                          coverImg: coverImage?.path ?? '',
                          visualVideo: visualVideo?.path ?? '',
                          // Invités : `[{"user_id":12,"share_pct":30}]`,
                          // omis s'il n'y en a pas.
                          guests: _guests.isEmpty
                              ? null
                              : jsonEncode(
                                  _guests.map((g) => g.toShareJson()).toList(),
                                ),
                        );
                      }
                    },
                    labelColor: whiteColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
