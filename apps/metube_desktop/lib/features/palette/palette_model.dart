import 'package:flutter/widgets.dart';
import 'package:mt_media/library.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

/// One thing the palette can run: a place, a section, a list.
class PaletteCommand {
  const PaletteCommand({
    required this.label,
    required this.icon,
    required this.run,
  });

  final String label;
  final MTIconData icon;
  final VoidCallback run;
}

/// A clip whose words were said: its best moment, and how many there are.
typedef SaidMatch = ({LibraryItem item, TranscriptHit hit, int total});

/// What the palette shows for one query.
class PaletteResults {
  const PaletteResults({
    this.commands = const [],
    this.titles = const [],
    this.said = const [],
    this.canSave = false,
  });

  final List<PaletteCommand> commands;
  final List<LibraryItem> titles;
  final List<SaidMatch> said;

  /// Whether "Save this search" is offered: a real query, not a command,
  /// and not one already saved.
  final bool canSave;

  bool get isEmpty =>
      commands.isEmpty && titles.isEmpty && said.isEmpty && !canSave;
}

/// What starts a query that only runs commands.
const paletteCommandMark = '>';

/// Enough rows of each kind to choose from without scrolling far.
const paletteTitlesShown = 8;
const paletteSaidShown = 8;
const paletteCommandsBeside = 4;

/// **The palette's ranking**: titles and what was said for a query, the
/// commands whose names fit it, and nothing but commands after `>`.
///
/// Every comparison goes through [SearchText.fold], so a word typed
/// without a hamza or vowel marks finds a title written with them, the
/// same way the transcripts are searched.
PaletteResults paletteResults({
  required String query,
  required List<LibraryItem> items,
  required List<PaletteCommand> commands,
  TranscriptIndex? index,
  Set<String> savedQueries = const {},
}) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return PaletteResults(commands: commands);
  if (trimmed.startsWith(paletteCommandMark)) {
    final rest = trimmed.substring(paletteCommandMark.length);
    return PaletteResults(commands: _fitting(commands, rest));
  }
  final words = SearchText.wordsOf(trimmed);
  final titles = <LibraryItem>[
    for (final item in items)
      if (_hasAll(item.title, words)) item,
  ].take(paletteTitlesShown).toList();

  final byUrl = {for (final item in items) item.canonicalUrl: item};
  final said = <SaidMatch>[
    // A clip no longer in the library keeps its transcript, but there is
    // nothing to open.
    for (final clip in index?.search(trimmed, perClip: 1) ?? const <ClipHits>[])
      if (byUrl[clip.canonicalUrl] case final item?)
        (item: item, hit: clip.hits.first, total: clip.total),
  ].take(paletteSaidShown).toList();

  return PaletteResults(
    titles: titles,
    said: said,
    commands: _fitting(commands, trimmed).take(paletteCommandsBeside).toList(),
    canSave:
        trimmed.length >= TranscriptIndex.minQueryLength &&
        !savedQueries.contains(trimmed),
  );
}

List<PaletteCommand> _fitting(List<PaletteCommand> commands, String query) {
  final words = SearchText.wordsOf(query);
  if (words.isEmpty) return commands;
  return [
    for (final command in commands)
      if (_hasAll(command.label, words)) command,
  ];
}

bool _hasAll(String text, List<String> words) {
  final folded = SearchText.fold(text);
  return words.every(folded.contains);
}
