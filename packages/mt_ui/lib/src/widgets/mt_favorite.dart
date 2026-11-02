import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_polish.dart';

import '../icons/mt_icon.dart';
import '../icons/mt_icons.dart';

/// **A favourite's mark on a phone card**: a small crimson heart before the
/// channel name, a status rather than a button.
///
/// Phones show it instead of an empty heart on every card, which said
/// nothing on most of them and sat where a thumb reaches for play. Toggling
/// moves to the item menu and the players ([MTFavoriteTile],
/// [MTFavoriteButton]). The card's own label already says "favourite" to a
/// screen reader, so the mark is silent.
class MTFavoriteMark extends StatelessWidget {
  const MTFavoriteMark({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: MTSpace.xxs),
    child: ExcludeSemantics(
      child: MTIcon(
        MTIcons.favoriteOn,
        size: 12,
        color: MTThemeX.of(context).palette.favorite,
      ),
    ),
  );
}

/// The first row of an item menu: add to or remove from the favourites.
class MTFavoriteTile extends StatelessWidget {
  const MTFavoriteTile({
    super.key,
    required this.favorite,
    required this.onTap,
  });

  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    return ListTile(
      leading: MTIcon(
        favorite ? MTIcons.favoriteOn : MTIcons.favorite,
        color: favorite ? p.favorite : p.ink2,
      ),
      title: Text(
        favorite ? l10n.removeFromFavorites : l10n.addToFavorites,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      onTap: onTap,
    );
  }
}

/// The heart beside a player's title: one tap while listening, the moment
/// someone knows they liked a clip.
class MTFavoriteButton extends StatelessWidget {
  const MTFavoriteButton({
    super.key,
    required this.favorite,
    required this.onPressed,
  });

  final bool favorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    return IconButton(
      tooltip: favorite ? l10n.removeFromFavorites : l10n.addToFavorites,
      onPressed: onPressed,
      icon: MTIconSwap(
        icon: favorite ? MTIcons.favoriteOn : MTIcons.favorite,
        size: 22,
        color: favorite ? p.favorite : p.ink3,
      ),
    );
  }
}
