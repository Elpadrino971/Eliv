import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/services/moderation_service.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Liste des comptes bloqués, avec déblocage.
///
/// Exigence App Store 1.2 : le blocage doit être réversible par l'utilisateur
/// lui-même, sans passer par le support.
class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  List _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await ModerationService.blockedUsers();
    if (!mounted) return;
    setState(() {
      _accounts = rows;
      _loading = false;
    });
  }

  Future<void> _unblock(int id) async {
    final ok = await ModerationService.unblockUser(id);
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'mod_blocked_title'.tr),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: goldPrimary))
          : _accounts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'mod_blocked_empty'.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: textMuted, fontSize: 15),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: goldPrimary,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _accounts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xff1B2740)),
                    itemBuilder: (context, i) {
                      final a = _accounts[i] as Map;
                      final id = int.tryParse('${a['id']}') ?? 0;
                      final name = '${a['name'] ?? ''}';
                      final image = '${a['profile_image'] ?? ''}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: cardDeep,
                          backgroundImage: image.startsWith('http') ? NetworkImage(image) : null,
                          child: image.startsWith('http')
                              ? null
                              : Text(
                                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                                  style: const TextStyle(color: goldPrimary, fontWeight: FontWeight.bold),
                                ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(color: ivory, fontWeight: FontWeight.w600),
                        ),
                        trailing: TextButton(
                          onPressed: () => _unblock(id),
                          child: Text(
                            'mod_unblock'.tr,
                            style: const TextStyle(color: goldPrimary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
