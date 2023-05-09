import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_misskey_app/providers.dart';
import 'package:flutter_misskey_app/router/app_router.dart';
import 'package:flutter_misskey_app/view/users_list_page/users_list_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommonDrawer extends ConsumerWidget {
  const CommonDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: ListView(
          children: [
            for (final account in ref.read(accountRepository).account) ...[
              Text(
                "@${account.userId}@${account.host}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text("通知"),
                onTap: () =>
                    context.pushRoute(NotificationRoute(account: account)),
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text("お気に入り"),
                onTap: () =>
                    context.pushRoute(FavoritedNoteRoute(account: account)),
              ),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text("リスト"),
                onTap: () =>
                    context.pushRoute(UsersListRoute(account: account)),
              ),
              ListTile(
                leading: const Icon(Icons.settings_input_antenna),
                title: Text("アンテナ"),
                onTap: () => context.pushRoute(AntennaRoute(account: account)),
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text("クリップ"),
                onTap: () => context.pushRoute(ClipListRoute(account: account)),
              ),
              ListTile(
                  leading: const Icon(Icons.tv),
                  title: const Text("チャンネル"),
                  onTap: () =>
                      context.pushRoute(ChannelsRoute(account: account))),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text("検索"),
                onTap: () =>
                    context.pushRoute(NoteSearchRoute(account: account)),
              )
            ],
            ListTile(
                leading: const Icon(Icons.settings),
                onTap: () => context.pushRoute(const SettingsRoute()),
                title: Text("設定")),
          ],
        ),
      ),
    );
  }
}
