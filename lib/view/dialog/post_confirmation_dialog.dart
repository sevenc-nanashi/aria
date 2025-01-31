import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:misskey_dart/misskey_dart.dart';

import '../../extension/notes_create_request_extension.dart';
import '../../i18n/strings.g.dart';
import '../../model/account.dart';
import '../../model/post_file.dart';
import '../../provider/api/attaches_notifier_provider.dart';
import '../../provider/api/channel_notifier_provider.dart';
import '../../provider/api/i_notifier_provider.dart';
import '../../provider/api/post_notifier_provider.dart';
import '../widget/note_widget.dart';

Future<bool> confirmPost(
  BuildContext context,
  Account account, {
  String? noteId,
  NotesCreateRequest? request,
  List<DriveFile>? files,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => PostConfirmationDialog(
      account: account,
      noteId: noteId,
      request: request,
      files: files,
    ),
  );
  return result ?? false;
}

class PostConfirmationDialog extends ConsumerWidget {
  const PostConfirmationDialog({
    super.key,
    required this.account,
    this.noteId,
    this.request,
    this.files,
  });

  final Account account;
  final String? noteId;
  final NotesCreateRequest? request;
  final List<DriveFile>? files;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotesCreateRequest request = this.request ??
        ref.watch(postNotifierProvider(account, noteId: noteId));
    final files = this.files ??
        ref
            .watch(attachesNotifierProvider(account, noteId: noteId))
            .map((file) => file is DrivePostFile ? file.file : null)
            .nonNulls
            .toList();
    final i = ref.watch(iNotifierProvider(account)).valueOrNull;
    final channel = request.channelId != null
        ? ref
            .watch(channelNotifierProvider(account, request.channelId!))
            .valueOrNull
        : null;
    final note = request.toNote(i: i, channel: channel);

    return Dialog(
      child: Container(
        width: 800.0,
        margin: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    request.isRenote
                        ? t.aria.renoteConfirm
                        : t.aria.postConfirm,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              if (request.isRenote)
                NoteWidget(account: account, noteId: request.renoteId!)
              else
                NoteWidget(
                  account: account,
                  noteId: '',
                  note: note.copyWith(files: files),
                  showFooter: false,
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () => context.pop(true),
                        child: Text(t.misskey.ok),
                      ),
                      const SizedBox(width: 8.0),
                      OutlinedButton(
                        onPressed: () => context.pop(false),
                        child: Text(t.misskey.cancel),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
