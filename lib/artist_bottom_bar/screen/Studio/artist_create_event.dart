import 'dart:io';

import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/app_date.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
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
    '19.99', '29.99', '39.99', '49.99', '59.99',
    '79.99', '99.99',
  ];
  String? selectedPrice;

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
                  hintText: 'Choisir un prix',
                  items: _ticketTiers.map((t) => '$t €').toList(),
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

                height(0.008),
                // Suggestion de prix (aide à la conversion). La grille est déjà
                // en charm pricing (.99) ; on met en avant le palier le plus
                // performant pour guider l'artiste sans le contraindre.
                Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '49,99 € est le tarif le plus choisi (« Populaire »). '
                        'Entre 39,99 € et 49,99 €, c\'est le meilleur rapport ventes / revenu.',
                        style: const TextStyle(
                          color: Color(0xffE6C76A),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                height(0.01),

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
                MyButton(
                  label: 'ev_publish'.tr,
                  onTap: () {
                    if (formKey.currentState!.validate()) {
                      if (coverImage == null) {
                        Get.snackbar('art_error'.tr, 'art_err_cover'.tr);
                        return;
                      }
                      if (visualVideo == null) {
                        Get.snackbar('art_error'.tr, 'art_err_visual'.tr);
                        return;
                      }

                      // Call API logic
                      final selectedGenreId = artistController
                          .genres
                          .value
                          .genre
                          ?.firstWhere((e) => e.genre == selectedGenre)
                          .id;

                      artistController.createEvent(
                        name: titleController.text,
                        description: descriptionController.text,
                        // Envoye en UTC (avec 'Z') pour que chaque spectateur
                        // voie l'heure dans son propre fuseau.
                        startDateTime: AppDate.localPartsToUtcIso(
                          startDateController.text,
                          startTimeController.text,
                        ),
                        endDateTime: AppDate.localPartsToUtcIso(
                          endDateController.text,
                          endTimeController.text,
                        ),
                        ticketPrice:
                            (selectedPrice ?? '0').replaceAll(' €', ''),
                        genreId: selectedGenreId?.toString() ?? '',
                        hasLiveChat: liveValue ? '1' : '0',
                        replayEnabled: replayEnabled ? '1' : '0',
                        replayDurationDays: '$replayDurationDays',
                        coverImg: coverImage?.path ?? '',
                        visualVideo: visualVideo?.path ?? '',
                      );
                    }
                  },
                  labelColor: whiteColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
