import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/homeScreen/check_out_screen.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/ZegoCloud/join_stream.dart';
import 'package:artist/ZegoCloud/pre_stream_screen.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class FutureScreen extends StatefulWidget {
  const FutureScreen({super.key, required this.event});
  final Event event;

  @override
  State<FutureScreen> createState() => _FutureScreenState();
}

class _FutureScreenState extends State<FutureScreen> {
  final eventController = Get.find<EventController>();

  final List<Map> futureList = [
    {'name': '4K Ultra HD Streaming', 'icon': Icons.high_quality_rounded},
    {'name': 'Dolby Atmos Spatial Audio', 'icon': Icons.surround_sound_rounded},
    {'name': 'Exclusive Digital Merch', 'icon': Icons.shopping_bag_outlined},
    {'name': 'Live Chat with VIP Fans', 'icon': Icons.chat_bubble_outline_rounded},
  ];

  // Paliers : Standard (prix reel), Premium (x2), VIP (x5)
  final List<Map> tiers = [
    {
      'name': 'STANDARD',
      'icon': Icons.person_outline_rounded,
      'tag': 'Access to live stream',
      'mult': 1,
    },
    {
      'name': 'PREMIUM',
      'icon': Icons.star_outline_rounded,
      'tag': 'Best quality + extras',
      'mult': 2,
    },
    {
      'name': 'VIP',
      'icon': Icons.workspace_premium_outlined,
      'tag': 'All access + VIP perks',
      'mult': 5,
    },
  ];
  int selectedTier = 1; // Premium par defaut (le plus populaire)

  Event event = Event();
  var like = false;

  Future myInitMethod() async {
    await eventController.getUserJoinedEvents();
  }

  @override
  void initState() {
    super.initState();
    event = widget.event;
  }

  double get _basePrice => double.tryParse(event.ticketPrice ?? '') ?? 0;
  double _tierPrice(int i) => _basePrice * (tiers[i]['mult'] as int);
  String _money(double v) =>
      '\$${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

  bool get _hasTicket =>
      (event.ticketBuyerIds ?? []).contains(userModel.value.user?.id ?? 1);

  /// Bouton circulaire "glass" premium (bleu nuit + contour or).
  Widget _glassButton({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: midnightPrimary.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: goldSecondary.withValues(alpha: 0.5)),
        ),
        child: child,
      ),
    );
  }

  /// Petite info compacte (icone or + texte).
  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: goldPrimary, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: ivory,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _metaDivider() => Container(
        width: 1,
        height: 16,
        color: goldSecondary.withValues(alpha: 0.3),
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );

  /// Chip de feature (badge icone or + label).
  Widget _featureChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: goldPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: goldPrimary, size: 15),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: ivory,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _tierCard(int index) {
    final selected = selectedTier == index;
    final popular = index == 1;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: BoxDecoration(
        gradient: selected ? null : kCardGradient,
        color: selected ? goldPrimary.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? goldPrimary : goldSecondary.withValues(alpha: 0.25),
          width: selected ? 1.8 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: goldPrimary.withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tiers[index]['icon'] as IconData,
            color: selected ? goldPrimary : ivory,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            tiers[index]['name'] as String,
            style: const TextStyle(
              color: ivory,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _money(_tierPrice(index)),
            style: TextStyle(
              color: selected ? goldPrimary : ivory,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tiers[index]['tag'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textMuted,
              fontSize: 10.5,
              height: 1.2,
            ),
          ),
        ],
      ),
    );

    final tappable = GestureDetector(
      onTap: () => setState(() => selectedTier = index),
      child: card,
    );

    if (!popular) return tappable;

    return GestureDetector(
      onTap: () => setState(() => selectedTier = index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            top: -11,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: kGoldGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(
                    color: midnightPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLive = event.status == 'live';
    return Scaffold(
      backgroundColor: midnightPrimary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Héro : image plein écran + dégradé + overlay
          SizedBox(
            width: Get.width,
            height: Get.height * 0.46,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageWidget(
                  url: '${APIs.eventImageIP}/${event.coverImage}',
                  fit: BoxFit.cover,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99071426), Color(0x00071426), Color(0xFF071426)],
                      stops: [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: myPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      height(0.03),
                      Row(
                        children: [
                          _glassButton(
                            onTap: () => Get.back(),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: ivory,
                              size: 18,
                            ),
                          ),
                          const Spacer(),
                          _glassButton(
                            onTap: () => setState(() => like = !like),
                            child: Icon(
                              like
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: like ? goldPrimary : ivory,
                              size: 18,
                            ),
                          ),
                          width(0.02),
                          _glassButton(
                            onTap: () async {
                              await myShare(message: APIs.mainIP);
                            },
                            child: const Icon(
                              Icons.ios_share_rounded,
                              color: ivory,
                              size: 18,
                            ),
                          ),
                          width(0.02),
                          _glassButton(
                            onTap: _showReportSheet,
                            child: const Icon(
                              Icons.more_vert,
                              color: ivory,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Badge LIVE / LIVE CONCERT
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isLive
                              ? liveRed
                              : midnightPrimary.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: isLive
                              ? null
                              : Border.all(
                                  color: goldSecondary.withValues(alpha: 0.5),
                                ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              color: isLive ? Colors.white : goldPrimary,
                              size: 8,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isLive ? 'LIVE NOW' : 'LIVE CONCERT',
                              style: TextStyle(
                                color: isLive ? Colors.white : ivory,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      height(0.012),
                      Text(
                        event.name?.capitalize ?? 'N/A',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ivory,
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          height: 1.05,
                          fontFamily: 'Google Sans',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (event.artist?.artistName ?? 'Live Stream')
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: goldPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      height(0.015),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Contenu défilant
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                myPadding.horizontal / 2,
                10,
                myPadding.horizontal / 2,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne date / heure compacte
                  Row(
                    children: [
                      _metaItem(
                        Icons.calendar_month_rounded,
                        DateFormat('MMM dd, yyyy').format(event.startDateTime!),
                      ),
                      _metaDivider(),
                      _metaItem(
                        Icons.schedule_rounded,
                        DateFormat('HH:mm a').format(event.startDateTime!),
                      ),
                    ],
                  ),
                  height(0.02),
                  // Chips de features
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      _featureChip(Icons.high_quality_rounded, '4K Ultra HD'),
                      _featureChip(Icons.surround_sound_rounded, 'Dolby Atmos'),
                      _featureChip(
                        Icons.chat_bubble_outline_rounded,
                        'VIP Fan Chat',
                      ),
                    ],
                  ),
                  height(0.025),

                  if (!_hasTicket) ...[
                    // ── Choix du palier
                    const Text(
                      'CHOOSE YOUR ACCESS',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _tierCard(0)),
                          const SizedBox(width: 10),
                          Expanded(child: _tierCard(1)),
                          const SizedBox(width: 10),
                          Expanded(child: _tierCard(2)),
                        ],
                      ),
                    ),
                    height(0.025),
                  ],

                  // ── Inclus
                  Container(
                    width: Get.width,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: kCardGradient,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: goldSecondary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasTicket
                              ? 'INCLUDED WITH YOUR PASS'
                              : 'INCLUDED WITH ${tiers[selectedTier]['name']}',
                          style: const TextStyle(
                            color: goldPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        height(0.018),
                        ...List.generate(futureList.length, (index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom:
                                  index == futureList.length - 1 ? 0 : 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: goldPrimary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    futureList[index]['icon'] as IconData,
                                    color: goldPrimary,
                                    size: 17,
                                  ),
                                ),
                                width(0.035),
                                Expanded(
                                  child: Text(
                                    futureList[index]['name'],
                                    style: const TextStyle(
                                      color: ivory,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  height(0.025),

                  // ── À propos
                  const Text(
                    'ABOUT THIS EVENT',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  height(0.012),
                  Text(
                    event.description ?? 'N/A',
                    style: const TextStyle(
                      color: textMuted,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),

                  // ── Bouton "Join Room" (jour J, avant le live)
                  if (canJoinRoom()) ...[
                    height(0.025),
                    MyButton(
                      label: 'Join Room',
                      buttonColor: Colors.transparent,
                      borderColor: goldPrimary,
                      labelColor: goldPrimary,
                      onTap: () async {
                        await Get.to(() => PreStreamScreen(event: event));
                        await myInitMethod();
                        final data = eventController.userJoinedEvents.value.data
                            ?.firstWhere((element) => element.id == event.id);
                        data != null ? event = data : null;
                        setState(() {});
                      },
                    ),
                  ],
                  height(0.01),
                ],
              ),
            ),
          ),

          // ── Barre CTA sticky (toujours visible)
          _buildStickyBar(isLive),
        ],
      ),
    );
  }

  Widget _buildStickyBar(bool isLive) {
    final bool hasTicket = _hasTicket;

    Widget content;
    if (hasTicket) {
      // Déjà acheté : action selon le statut de l'event
      final completed = event.status == 'completed';
      content = MyButton(
        label: isLive
            ? 'Join Event'
            : completed
                ? 'Event Completed'
                : 'Wait for Live',
        image: 'assets/arrow.png',
        imageColor: midnightPrimary,
        labelColor: midnightPrimary,
        buttonColor: (isLive) ? null : greyColor.withValues(alpha: 0.4),
        onTap: (!isLive || completed)
            ? () {}
            : () async {
                await Get.to(() => JoinStream(event: event));
                await myInitMethod();
                final data = eventController.userJoinedEvents.value.data
                    ?.firstWhere((element) => element.id == event.id);
                data != null ? event = data : null;
                setState(() {});
              },
      );
    } else {
      // Pas encore acheté : prix du palier + checkout
      content = Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Total',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
              Text(
                _money(_tierPrice(selectedTier)),
                style: const TextStyle(
                  color: ivory,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${(tiers[selectedTier]['name'] as String).capitalizeFirst} Access',
                style: const TextStyle(color: textMuted, fontSize: 11),
              ),
            ],
          ),
          width(0.04),
          Expanded(
            child: MyButton(
              label: 'CONTINUE TO CHECKOUT',
              image: 'assets/arrow.png',
              imageColor: midnightPrimary,
              labelColor: midnightPrimary,
              onTap: () async {
                final tierName = tiers[selectedTier]['name'] as String;
                final value = await Get.to(
                  () => CheckOutScreen(
                    event: event,
                    tierTitle:
                        '${tierName.capitalizeFirst} Pass',
                    tierSubtitle: tiers[selectedTier]['tag'] as String,
                    tierPrice: _money(_tierPrice(selectedTier)),
                  ),
                );
                if (value != null) {
                  event = event.copyWith(
                    ticketBuyerIds: [
                      ...(event.ticketBuyerIds ?? []),
                      userModel.value.user?.id ?? 1,
                    ],
                  );
                  setState(() {});
                }
              },
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: midnightSecondary,
        border: Border(
          top: BorderSide(color: goldSecondary.withValues(alpha: 0.2)),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: content,
        ),
      ),
    );
  }

  void _showReportSheet() {
    String selectedReason = '';
    final otherReasonController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: cardDeep,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: goldSecondary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    height(0.02),
                    const Text(
                      'Report Event',
                      style: TextStyle(
                        color: ivory,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Please select a reason for reporting this event.',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    height(0.02),
                    ...[
                      'Spam',
                      'Inappropriate Content',
                      'Harassment',
                      'Copyright Issue',
                      'Other',
                    ].map((reason) {
                      return RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          reason,
                          style: const TextStyle(
                            color: ivory,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: goldPrimary,
                        onChanged: (value) {
                          setModalState(() {
                            selectedReason = value!;
                          });
                        },
                      );
                    }),
                    if (selectedReason == 'Other') ...[
                      height(0.01),
                      MyTextField(
                        hintText: 'Enter your reason...',
                        controller: otherReasonController,
                      ),
                    ],
                    height(0.02),
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: ivory,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    height(0.01),
                    MyTextField(
                      hintText: 'Provide more details...',
                      controller: descController,
                      maxLines: 4,
                    ),
                    height(0.03),
                    MyButton(
                      label: 'Submit Report',
                      onTap: () async {
                        String finalReason = selectedReason == 'Other'
                            ? otherReasonController.text.trim()
                            : selectedReason;

                        if (finalReason.isEmpty) {
                          myWarningDialog(
                            subtitle: 'Please select or enter a reason.',
                          );
                          return;
                        }

                        myLoadingDialog();
                        await eventController.reportEvent(
                          eventId: '${event.id}',
                          reason: finalReason,
                          description: descController.text.trim(),
                        );
                        Get.back(); // close loading
                        Get.back(); // close sheet

                        mySuccessDialog(
                          subtitle:
                              'Report submitted. We will review it shortly.',
                          ontap: () => Get.back(),
                        );
                      },
                      labelColor: whiteColor,
                    ),
                    height(0.01),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool canJoinRoom() {
    return (event.startDateTime != null &&
        DateTime.now().year == event.startDateTime!.year &&
        DateTime.now().month == event.startDateTime!.month &&
        DateTime.now().day == event.startDateTime!.day &&
        DateTime.now().isBefore(event.startDateTime!));
  }
}
