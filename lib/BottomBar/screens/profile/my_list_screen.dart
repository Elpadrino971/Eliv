import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Ma liste" : les artistes que le user a enregistrés (façon Netflix).
/// Alimenté par GET /api/my-list. Un tap ouvre la fiche de l'artiste.
class MyListScreen extends StatefulWidget {
  const MyListScreen({super.key});

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  final eventController = Get.find<EventController>();

  @override
  void initState() {
    super.initState();
    eventController.getMyList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Ma liste'),
      body: Obx(() {
        if (eventController.myListLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final artists = eventController.myListArtists;
        if (artists.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.playlist_add_rounded,
                      color: greyColor, size: 56),
                  const SizedBox(height: 14),
                  Text(
                    'Ta liste est vide',
                    style: TextStyle(
                      color: Get.isDarkMode ? whiteColor : blackColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ajoute des artistes avec « + Ma liste » sur leur fiche.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: greyColor, fontSize: 13.5),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: artists.length,
          separatorBuilder: (_, __) =>
              Divider(color: greyColor.withValues(alpha: 0.15), height: 1),
          itemBuilder: (context, i) {
            final a = artists[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              onTap: () => Get.to(() => ArtistDetailScreen(artist: a)),
              leading: ClipOval(
                child: ImageWidget(
                  url: a.profileImage ?? a.artistProfile ?? '',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                a.artistName ?? a.fullName ?? 'Artiste',
                style: TextStyle(
                  color: Get.isDarkMode ? whiteColor : blackColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              subtitle: (a.artistBio ?? a.bio) != null &&
                      (a.artistBio ?? a.bio)!.trim().isNotEmpty
                  ? Text(
                      (a.artistBio ?? a.bio)!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: greyColor, fontSize: 12.5),
                    )
                  : null,
              trailing: Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: goldPrimary.withValues(alpha: 0.6)),
            );
          },
        );
      }),
    );
  }
}
