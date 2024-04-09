import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:json5/json5.dart';
import 'package:misskey_dart/misskey_dart.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../i18n/strings.g.dart';
import '../../../model/account.dart';
import '../../../model/account_settings.dart';
import '../../../model/general_settings.dart';
import '../../../model/tab_settings.dart';
import '../../../provider/account_settings_notifier_provider.dart';
import '../../../provider/accounts_notifier_provider.dart';
import '../../../provider/api/drive_files_notifier_provider.dart';
import '../../../provider/api/misskey_provider.dart';
import '../../../provider/cache_manager_provider.dart';
import '../../../provider/file_system_provider.dart';
import '../../../provider/general_settings_notifier_provider.dart';
import '../../../provider/timeline_tabs_notifier_provider.dart';
import '../../../util/copy_text.dart';
import '../../../util/format_datetime.dart';
import '../../../util/future_with_dialog.dart';
import '../../dialog/confirmation_dialog.dart';
import '../../dialog/message_dialog.dart';
import '../../dialog/radio_dialog.dart';
import '../../dialog/text_field_dialog.dart';
import '../drive_page.dart';

class ImportExportPage extends ConsumerWidget {
  const ImportExportPage({super.key});

  Future<Map<String, dynamic>> _export(WidgetRef ref) async {
    final accounts = ref.read(accountsNotifierProvider);
    final packageInfo = await PackageInfo.fromPlatform();
    return {
      'metadata': {
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'packageInfo': packageInfo.data,
        'platform': defaultTargetPlatform.name,
      },
      'timelineTabs': ref.read(timelineTabsNotifierProvider),
      'accountSettings': {
        for (final account in accounts)
          '$account': ref.read(accountSettingsNotifierProvider(account)),
      },
      'generalSettings': ref.read(generalSettingsNotifierProvider),
    };
  }

  Future<void> _import(WidgetRef ref, Map<String, dynamic> json) async {
    if (json case {'timelineTabs': final List<dynamic> json}) {
      final tabs = json
          .map((json) {
            try {
              return TabSettings.fromJson(json as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .nonNulls
          .toList();
      await ref.read(timelineTabsNotifierProvider.notifier).import(tabs);
    }
    if (json case {'accountSettings': final Map<String, dynamic> json}) {
      for (final e in json.entries) {
        try {
          final account = Account.fromString(e.key);
          final accountSettings =
              AccountSettings.fromJson(e.value as Map<String, dynamic>);
          await ref
              .read(accountSettingsNotifierProvider(account).notifier)
              .import(accountSettings);
        } catch (_) {}
      }
    }
    if (json case {'generalSettings': final Map<String, dynamic> json}) {
      try {
        final generalSettings = GeneralSettings.fromJson(json);
        await ref
            .read(generalSettingsNotifierProvider.notifier)
            .import(generalSettings);
      } catch (_) {}
    }
  }

  Future<Account?> _selectAccount(
    BuildContext context,
    List<Account> accounts,
  ) async {
    return showRadioDialog(
      context,
      title: Text(t.misskey.selectAccount),
      values: accounts,
      itemBuilder: (context, account) => Text(account.toString()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.misskey.importAndExport)),
      body: ListView(
        children: [
          ExpansionTile(
            leading: const Icon(Icons.file_upload),
            title: Text(t.misskey.export),
            initiallyExpanded: true,
            children: [
              if (accounts.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.cloud),
                  title: Text(t.misskey.drive),
                  onTap: () async {
                    final account = await _selectAccount(context, accounts);
                    if (!context.mounted) return;
                    if (account != null) {
                      final result = await showDialog<(DriveFolder?,)>(
                        context: ref.context,
                        builder: (context) => DrivePage(
                          account: account,
                          selectFolder: true,
                        ),
                      );
                      if (!context.mounted) return;
                      if (result == null) return;
                      final folderId = result.$1?.id;
                      final tempDirectory = await ref
                          .read(fileSystemProvider)
                          .systemTempDirectory
                          .createTemp();
                      final tempFile = tempDirectory.childFile('aria.json');
                      await tempFile
                          .writeAsString(jsonEncode(await _export(ref)));
                      if (!context.mounted) return;
                      await futureWithDialog(
                        context,
                        ref
                            .read(
                              driveFilesNotifierProvider(account, folderId)
                                  .notifier,
                            )
                            .upload(
                              tempFile,
                              comment: t.aria.settingsFileForAria,
                            ),
                        message: t.aria.uploaded,
                      );
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(t.misskey.copy),
                onTap: () async {
                  final data = await _export(ref);
                  if (!context.mounted) return;
                  copyToClipboard(context, jsonEncode(data));
                },
              ),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.file_download),
            title: Text(t.misskey.import),
            initiallyExpanded: true,
            children: [
              if (accounts.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.cloud),
                  title: Text(t.misskey.drive),
                  onTap: () async {
                    final account = await _selectAccount(context, accounts);
                    if (!context.mounted) return;
                    if (account != null) {
                      final result = await showDialog<(DriveFolder?,)>(
                        context: ref.context,
                        builder: (context) => DrivePage(
                          account: account,
                          selectFolder: true,
                        ),
                      );
                      if (!context.mounted) return;
                      if (result == null) return;
                      final folderId = result.$1?.id;
                      if (!context.mounted) return;
                      final files = await futureWithDialog(
                        context,
                        Future.wait(
                          ['aria.json', 'aria.json.unknown'].map(
                            (name) => ref
                                .read(misskeyProvider(account))
                                .drive
                                .files
                                .find(
                                  DriveFilesFindRequest(
                                    name: name,
                                    folderId: folderId,
                                  ),
                                ),
                          ),
                        ),
                      );
                      if (files == null) return;
                      final latest = files.flattened
                          .sortedBy((file) => file.createdAt)
                          .lastOrNull;
                      if (latest != null) {
                        if (!context.mounted) return;
                        final file = await futureWithDialog(
                          context,
                          ref
                              .read(cacheManagerProvider)
                              .getSingleFile(latest.url),
                        );
                        try {
                          final json = json5Decode(await file!.readAsString())
                              as Map<String, dynamic>;
                          if (!context.mounted) return;
                          final confirmed = await confirm(
                            context,
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.aria.importConfirm),
                                Text(
                                  '${t.misskey.createdAt}: ${absoluteTime(latest.createdAt)}',
                                ),
                              ],
                            ),
                          );
                          if (!context.mounted) return;
                          if (confirmed) {
                            await _import(ref, json);
                            if (!context.mounted) return;
                            await showMessageDialog(
                              context,
                              t.aria.importCompleted,
                            );
                          }
                        } catch (_) {
                          if (!context.mounted) return;
                          await showMessageDialog(
                            context,
                            t.misskey.invalidValue,
                          );
                        }
                      }
                    } else {
                      await showMessageDialog(context, t.aria.fileNotFound);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.paste),
                title: Text(t.aria.paste),
                onTap: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => TextFieldDialog(
                      title: Text(t.aria.paste),
                      maxLines: 10,
                    ),
                  );
                  if (result != null) {
                    try {
                      final json = json5Decode(result) as Map<String, dynamic>;
                      if (!context.mounted) return;
                      final confirmed = await confirm(
                        context,
                        message: t.aria.importConfirm,
                      );
                      if (!context.mounted) return;
                      if (confirmed) {
                        await _import(ref, json);
                        if (!context.mounted) return;
                        await showMessageDialog(
                          context,
                          t.aria.importCompleted,
                        );
                      }
                    } catch (_) {
                      if (!context.mounted) return;
                      await showMessageDialog(context, t.misskey.invalidValue);
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
