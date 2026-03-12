import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../screens/profile_screen.dart';
import '../screens/search/global_search_delegate.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool centerTitle;
  final bool transparent;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final List<Widget>? actions;

  const GlobalAppBar({
    super.key,
    this.title,
    this.centerTitle = false,
    this.transparent = false,
    this.bottom,
    this.leading,
    this.actions,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.userModel;

    return AppBar(
      backgroundColor: transparent ? Colors.transparent : null,
      elevation: transparent ? 0 : 4,
      centerTitle: centerTitle,
      title: title != null ? Text(title!) : null,
      bottom: bottom,
      leading:
          leading ??
          Builder(
            builder: (ctx) {
              // Try to find the root home scaffold first
              final homeScaffold = Scaffold.maybeOf(context);
              final currentScaffold = Scaffold.maybeOf(ctx);

              final canPop = Navigator.canPop(ctx);

              if (homeScaffold?.hasDrawer == true ||
                  currentScaffold?.hasDrawer == true) {
                return IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    if (currentScaffold?.hasDrawer == true) {
                      Scaffold.of(ctx).openDrawer();
                    } else if (homeScaffold?.hasDrawer == true) {
                      Scaffold.of(context).openDrawer();
                    }
                  },
                );
              } else if (canPop) {
                return const BackButton();
              }
              return const SizedBox.shrink();
            },
          ),
      actions:
          actions ??
          [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    try {
                      showSearch(
                        context: context,
                        delegate: GlobalSearchDelegate(),
                      );
                    } catch (e) {
                      debugPrint('GlobalAppBar search error: $e');
                    }
                  }
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GestureDetector(
                onTap: () {
                  // Optimization: Don't push ProfileScreen if we're already there
                  if (title == "My Profile") return;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    }
                  });
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: user != null && user.photoUrl.isNotEmpty
                      ? (user.photoUrl.startsWith('http')
                          ? CachedNetworkImageProvider(user.photoUrl)
                          : (kIsWeb
                              ? NetworkImage(user.photoUrl)
                              : FileImage(File(user.photoUrl)) as ImageProvider))
                      : null,
                  child: (user == null || user.photoUrl.isEmpty)
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
              ),
            ),
          ],
    );
  }
}
