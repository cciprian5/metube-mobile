import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/channels_data.dart';
import '../../shell/error_text.dart';
import '../../shell/choice_menu.dart';
import '../../shell/shell_metrics.dart';
import '../folders/folder_widgets.dart';
import '../folders/own_folder_field.dart';
import '../../shell/ember_dialog.dart';

/// Following a channel, or editing one already followed: one dialog,
/// since the fields are the same. The link cannot change on an edit (it
/// would be another channel, with another seen-list), and the quality is
/// asked once, when following, because the server will not change it
/// afterwards.
///
/// [name] heads a follow offered from a channel the library already has
/// clips from; the link is still the user's to paste.
Future<void> showFollowDialog(
  BuildContext context, {
  ChannelSubscription? editing,
  String? name,
}) => showEmberDialog<void>(
  context: context,
  builder: (_) => _FollowDialog(editing: editing, name: name),
);

class _FollowDialog extends ConsumerStatefulWidget {
  const _FollowDialog({this.editing, this.name});

  final ChannelSubscription? editing;
  final String? name;

  @override
  ConsumerState<_FollowDialog> createState() => _FollowDialogState();
}

class _FollowDialogState extends ConsumerState<_FollowDialog> {
  late final _url = TextEditingController(text: widget.editing?.url ?? '');
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _filter = TextEditingController(
    text: widget.editing?.titleRegex ?? '',
  );
  late int _interval = nearestChannelInterval(
    widget.editing?.checkIntervalMinutes ?? 60,
  );
  Quality _quality = Quality.best;
  late bool _ownFolder = widget.editing?.folder != null;
  late FolderChoice _folder = switch (widget.editing?.folder) {
    final folder? => FolderChoice(folder),
    null => FolderChoice.channel,
  };
  bool _busy = false;
  String? _failure;

  bool get _isEdit => widget.editing != null;

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    _filter.dispose();
    super.dispose();
  }

  /// The folder to send on an edit, or null when it has not changed. Off
  /// is the top of the downloads; an empty name is the channel's.
  String? _folderChange(ChannelSubscription sub) {
    final wanted = !_ownFolder
        ? ''
        : _folder.channelName
        ? channelFolderName(sub.name)
        : _folder.path;
    return wanted == (sub.folder ?? '') ? null : wanted;
  }

  Future<void> _submit() async {
    final l = context.mtl;
    final controller = ref.read(channelsControllerProvider);
    final filter = _filter.text.trim();
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final String message;
      if (widget.editing case final sub?) {
        final name = _name.text.trim();
        await controller.edit(
          sub,
          name: name.isEmpty ? sub.name : name,
          checkIntervalMinutes: _interval,
          titleRegex: filter,
          folder: _folderChange(sub),
        );
        message = l.done;
      } else {
        final url = _url.text.trim();
        final named = await controller.follow(
          url,
          quality: _quality,
          checkIntervalMinutes: _interval,
          titleRegex: filter.isEmpty ? null : filter,
          ownFolder: _ownFolder,
          folder: _folder.path,
        );
        // The title the server resolved is the proof the right channel
        // was followed.
        message = l.subscriptionAdded(mtName(named ?? url));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showMTNotice(context, message: message, kind: MTNoticeKind.done);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failure = isAlreadyFollowed(e) ? l.alreadySubscribed : errorText(l, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final canSubmit = !_busy && (_isEdit || _url.text.trim().isNotEmpty);
    const gap = SizedBox(height: MTSpace.md);
    return AlertDialog(
      title: Text(
        widget.editing?.name ?? widget.name ?? l.followChannel,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: EmberShellSize.formDialog,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isEdit)
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l.subscriptionName),
                )
              else
                TextField(
                  controller: _url,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => canSubmit ? unawaited(_submit()) : null,
                  decoration: InputDecoration(
                    labelText: l.channelUrl,
                    hintText: l.channelUrlHint,
                    hintTextDirection: TextDirection.ltr,
                  ),
                ),
              gap,
              EmberChoice<int>(
                label: l.checkEvery,
                value: _interval,
                onChanged: (v) => setState(() => _interval = v),
                choices: {
                  for (final minutes in channelIntervals)
                    minutes: minutes < 60
                        ? l.every30Minutes
                        : l.everyHours(minutes ~/ 60),
                },
              ),
              if (!_isEdit) ...[
                gap,
                EmberChoice<Quality>(
                  label: l.subscriptionQuality,
                  helper: l.subscriptionQualityNote,
                  value: _quality,
                  onChanged: (v) => setState(() => _quality = v),
                  choices: {
                    Quality.best: l.qualityBest,
                    Quality.q1080: l.quality1080,
                    Quality.q720: l.quality720,
                    Quality.q480: l.quality480,
                    Quality.audio: l.audioOnly,
                  },
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MTLinkButton(
                    label: l.helpAboutField,
                    onPressed: () => unawaited(
                      showFolderHelp(
                        context,
                        l.subscriptionQuality,
                        l.subscriptionQualityHelp,
                      ),
                    ),
                  ),
                ),
              ],
              gap,
              TextField(
                controller: _filter,
                decoration: InputDecoration(
                  labelText: l.titleFilter,
                  hintText: l.titleFilterHint,
                  helperText: l.titleFilterHelper,
                  helperMaxLines: 3,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MTLinkButton(
                  label: l.helpAboutField,
                  onPressed: () => unawaited(
                    showFolderHelp(context, l.titleFilter, l.titleFilterHelp),
                  ),
                ),
              ),
              gap,
              OwnFolderField(
                on: _ownFolder,
                choice: _folder,
                audio: _isEdit
                    ? widget.editing!.quality == Quality.audio.wire
                    : _quality == Quality.audio,
                onToggle: (on) => setState(() => _ownFolder = on),
                onPicked: (folder) => setState(() => _folder = folder),
              ),
              // The sentence that decides whether someone dares press the
              // button: nothing already on the channel is downloaded.
              if (!_isEdit) ...[
                gap,
                Text(
                  l.onlyNewVideos,
                  style: text.bodySmall?.copyWith(color: p.ink3),
                ),
              ],
              if (_failure case final why?) ...[
                gap,
                Text(why, style: text.bodySmall?.copyWith(color: p.err)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: canSubmit ? () => unawaited(_submit()) : null,
          child: _busy
              ? const MTSpinner(size: MTSpace.lg)
              : Text(_isEdit ? l.saveSettings : l.follow),
        ),
      ],
    );
  }
}
