import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../state/library_providers.dart';

/// A vertical strip of A-Z letters pinned to the trailing edge of the
/// library list. Tapping or dragging across it scrolls [scrollController]
/// to the first item whose sort key starts with that letter, firing a
/// selection-click haptic on every letter change and showing a large
/// floating letter bubble at the touch point while active — the same
/// interaction pattern as iOS's Contacts index and most native Android
/// music players.
class AzFastScroller extends StatefulWidget {
  final AzIndex index;
  final ScrollController scrollController;
  final double Function(int trackIndex) estimateOffsetForIndex;
  final bool visible;

  const AzFastScroller({
    super.key,
    required this.index,
    required this.scrollController,
    required this.estimateOffsetForIndex,
    this.visible = true,
  });

  @override
  State<AzFastScroller> createState() => _AzFastScrollerState();
}

class _AzFastScrollerState extends State<AzFastScroller> {
  String? _activeLetter;
  double? _bubbleY;
  final GlobalKey _stripKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final accent = AccentScope.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          bottom: 0,
          right: 2,
          child: GestureDetector(
            key: _stripKey,
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (details) =>
                _handleTouch(details.localPosition.dy),
            onVerticalDragUpdate: (details) =>
                _handleTouch(details.localPosition.dy),
            onVerticalDragEnd: (_) => _clearActive(),
            onVerticalDragCancel: _clearActive,
            onTapDown: (details) => _handleTouch(details.localPosition.dy),
            onTapUp: (_) => _clearActive(),
            child: Container(
              width: 22,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.transparent,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: AzIndex.alphabet.map((letter) {
                      final hasEntries =
                          widget.index.letterToFirstIndex.containsKey(letter);
                      final isActive = letter == _activeLetter;
                      return Text(
                        letter,
                        style: TextStyle(
                          fontSize: isActive ? 13 : 10,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: !hasEntries
                              ? Colors.white.withOpacity(0.18)
                              : isActive
                                  ? accent.primary
                                  : Colors.white.withOpacity(0.55),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ),
        if (_activeLetter != null && _bubbleY != null)
          Positioned(
            right: 44,
            top: _bubbleY! - 34,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: AppTokens.microInteraction,
                opacity: _activeLetter != null ? 1 : 0,
                child: Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevatedDark.withOpacity(0.92),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: accent.primary.withOpacity(0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Text(
                    _activeLetter!,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _handleTouch(double localDy) {
    final renderBox =
        _stripKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final height = renderBox.size.height;
    final clamped = localDy.clamp(0.0, height);
    final letterCount = AzIndex.alphabet.length;
    final rawIndex =
        (clamped / height * letterCount).floor().clamp(0, letterCount - 1);
    final letter = AzIndex.alphabet[rawIndex];

    if (letter != _activeLetter) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _activeLetter = letter;
      _bubbleY = localDy;
    });

    final targetTrackIndex = _resolveNearestIndex(letter);
    if (targetTrackIndex != null) {
      final offset = widget.estimateOffsetForIndex(targetTrackIndex);
      widget.scrollController.jumpTo(
        offset.clamp(0.0, widget.scrollController.position.maxScrollExtent),
      );
    }
  }

  /// If the touched letter has no tracks (e.g. dragged onto "Q" in a
  /// library with no artists starting with Q), falls forward to the
  /// nearest later letter that does, so the scroller never feels dead
  /// under the user's finger.
  int? _resolveNearestIndex(String letter) {
    final map = widget.index.letterToFirstIndex;
    if (map.containsKey(letter)) return map[letter];

    final startPos = AzIndex.alphabet.indexOf(letter);
    for (int i = startPos + 1; i < AzIndex.alphabet.length; i++) {
      final candidate = map[AzIndex.alphabet[i]];
      if (candidate != null) return candidate;
    }
    for (int i = startPos - 1; i >= 0; i--) {
      final candidate = map[AzIndex.alphabet[i]];
      if (candidate != null) return candidate;
    }
    return null;
  }

  void _clearActive() {
    setState(() {
      _activeLetter = null;
      _bubbleY = null;
    });
  }
}
