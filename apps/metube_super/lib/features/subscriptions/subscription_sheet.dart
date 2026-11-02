import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../settings/widgets/help_button.dart';
import '../shared/error_text.dart';
import '../folders/folder_picker.dart';
import 'subscription_fields.dart';
import 'subscriptions_providers.dart';

/// Following a channel, and editing one that is already followed.
///
/// **The same sheet for both** because the fields are the same three, and
/// the one difference — the URL cannot change, since changing it would be
/// a different channel with someone else's seen-list — is expressed by
/// disabling the field rather than by a second screen.
Future<void> showSubscriptionSheet(
  BuildContext context,
  WidgetRef ref, {
  ChannelSubscription? editing,
  String? url,
  String? name,
}) => showMTSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  // Above the whole app, as every sheet is: opened from a channel's page
  // inside a tab, it stayed in that tab and the add button floated over
  // it (field report 2026-11-01).
  useRootNavigator: true,
  builder: (_) => _SubscriptionSheet(editing: editing, url: url, name: name),
);

class _SubscriptionSheet extends ConsumerStatefulWidget {
  const _SubscriptionSheet({this.editing, this.url, this.name});

  final ChannelSubscription? editing;

  /// A channel to follow, already known (from the video player): the link
  /// is filled in and the user only chooses how to follow it.
  final String? url;
  final String? name;

  @override
  ConsumerState<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<_SubscriptionSheet> {
  late final _urlController = TextEditingController(
    text: widget.editing?.url ?? widget.url ?? '',
  );
  late final _nameController = TextEditingController(
    text: widget.editing?.name ?? widget.name ?? '',
  );
  late final _filterController = TextEditingController(
    text: widget.editing?.titleRegex ?? '',
  );
  late int _interval = _nearestInterval(
    widget.editing?.checkIntervalMinutes ?? 60,
  );
  late bool _ownFolder = widget.editing?.folder != null;
  late FolderChoice _folder = switch (widget.editing?.folder) {
    final folder? => FolderChoice(folder),
    null => FolderChoice.channel,
  };
  late Quality _quality = ref.read(settingsProvider).quality;
  bool _busy = false;

  bool get _isEdit => widget.editing != null;

  /// A server configured elsewhere can hold any interval at all, including
  /// one this sheet does not offer. Snapping to the nearest offered value
  /// keeps the dropdown from being empty, and the user only loses that
  /// exact number if they actually save.
  static int _nearestInterval(int minutes) {
    if (subscriptionIntervals.contains(minutes)) return minutes;
    return subscriptionIntervals.reduce(
      (a, b) => (a - minutes).abs() <= (b - minutes).abs() ? a : b,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  /// The folder to send when editing, or null when it has not changed. Off
  /// is the top of the download directory; an empty name is the channel's.
  String? _folderChange(ChannelSubscription sub) {
    final wanted = !_ownFolder
        ? ''
        : _folder.channelName
        ? channelFolderName(sub.name)
        : _folder.path;
    return wanted == (sub.folder ?? '') ? null : wanted;
  }

  Future<void> _pickFolder() async {
    final audio = _isEdit
        ? widget.editing!.quality == Quality.audio.wire
        : _quality == Quality.audio;
    // The channel field would take the focus back as the picker closes.
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showFolderPicker(
      context,
      audio: audio,
      current: _folder,
      // "No folder" is the switch turned off, so it is not offered twice.
      offerTop: false,
      offerChannelName: true,
    );
    if (picked != null && mounted) setState(() => _folder = picked);
  }

  Future<void> _submit() async {
    final l10n = context.mtl;
    final controller = ref.read(subscriptionsControllerProvider);
    final filter = _filterController.text.trim();
    setState(() => _busy = true);
    try {
      final String message;
      if (widget.editing case final sub?) {
        await controller.edit(
          sub,
          name: _nameController.text.trim(),
          checkIntervalMinutes: _interval,
          titleRegex: filter.isEmpty ? null : filter,
          // An emptied field is a deletion, and the server only reads keys
          // it is sent, so it has to be said explicitly.
          clearTitleRegex: filter.isEmpty,
          folder: _folderChange(sub),
        );
        message = l10n.done;
      } else {
        final name = await controller.follow(
          _urlController.text.trim(),
          quality: _quality,
          checkIntervalMinutes: _interval,
          titleRegex: filter.isEmpty ? null : filter,
          ownFolder: _ownFolder,
          folder: _folder.path,
        );
        // The server resolved the channel's real title; naming it is the
        // proof that the right channel was followed.
        message = l10n.subscriptionAdded(
          mtName(name ?? _urlController.text.trim()),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showMTSnack(context, message, type: MTSnackType.success);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // **The duplicate is named rather than passed through**: the server
      // answers in English whatever the interface language is.
      final duplicate =
          e is ServerErrorException &&
          (e.detail ?? '').toLowerCase().contains('already subscribed');
      showMTSnack(
        context,
        duplicate ? l10n.alreadySubscribed : errorText(l10n, e),
        type: MTSnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final canSubmit =
        !_busy && (_isEdit || _urlController.text.trim().isNotEmpty);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        MTSpace.pagePad,
        MTSpace.md,
        MTSpace.pagePad,
        mtSheetBottomPad(context),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? widget.editing!.name : l10n.followChannel,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: MTSpace.md),
            if (_isEdit)
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.subscriptionName),
              )
            else
              TextField(
                controller: _urlController,
                autofocus: true,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.channelUrl,
                  hintText: l10n.channelUrlHint,
                  hintTextDirection: TextDirection.ltr,
                ),
              ),
            const SizedBox(height: MTSpace.md),
            DropdownMenu<int>(
              trailingIcon: const MTIcon(MTIcons.chevronDown),
              selectedTrailingIcon: const MTIcon(MTIcons.chevronUp),
              initialSelection: _interval,
              label: Text(l10n.checkEvery),
              expandedInsets: EdgeInsets.zero,
              onSelected: (value) => setState(() => _interval = value ?? 60),
              dropdownMenuEntries: [
                for (final minutes in subscriptionIntervals)
                  DropdownMenuEntry(
                    value: minutes,
                    label: minutes < 60
                        ? l10n.every30Minutes
                        : l10n.everyHours(minutes ~/ 60),
                  ),
              ],
            ),
            // **The quality belongs to the subscription and the server
            // will not change it afterwards**, so it is asked once, when
            // following, and not offered as an edit that would silently do
            // nothing.
            if (!_isEdit) ...[
              const SizedBox(height: MTSpace.md),
              SubscriptionQualityField(
                value: _quality,
                onChanged: (value) => setState(() => _quality = value),
              ),
            ],
            const SizedBox(height: MTSpace.md),
            TextField(
              controller: _filterController,
              decoration: InputDecoration(
                labelText: l10n.titleFilter,
                hintText: l10n.titleFilterHint,
                helperText: l10n.titleFilterHelper,
                helperMaxLines: 3,
                // The line underneath covers the everyday use; the rest —
                // "or", letter case, and that a skipped video is never
                // fetched later — is asked for, not imposed (2026-09-25).
                suffixIcon: HelpButton(
                  title: l10n.titleFilter,
                  body: l10n.titleFilterHelp,
                ),
              ),
            ),
            const SizedBox(height: MTSpace.sm),
            SubscriptionFolderField(
              enabled: _ownFolder,
              value: _folder.channelName
                  ? l10n.channelNameFolder
                  : mtName(_folder.path),
              onToggle: (value) => setState(() => _ownFolder = value),
              onPick: _pickFolder,
            ),
            const SizedBox(height: MTSpace.md),
            // The one sentence that decides whether someone dares press
            // the button: nothing already on the channel is downloaded.
            if (!_isEdit)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MTIcon(MTIcons.info, size: 16, color: p.ink3),
                  const SizedBox(width: MTSpace.xs),
                  Expanded(
                    child: Text(
                      l10n.onlyNewVideos,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: p.ink3),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: MTSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canSubmit ? _submit : null,
                icon: _busy
                    ? const MTSpinner(size: 16)
                    : MTIcon(_isEdit ? MTIcons.check : MTIcons.addlink),
                label: Text(_isEdit ? l10n.saveSettings : l10n.follow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
