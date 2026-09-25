import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/player/audio_handler_provider.dart';
import '../../../core/theme/app_theme.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  late List<Track> _queue;
  late int _currentPosition;

  @override
  void initState() {
    super.initState();
    _refreshFromHandler();
  }

  void _refreshFromHandler() {
    final handler = ref.read(audioHandlerProvider);
    _queue = List.of(handler.currentQueueInPlayOrder());
    _currentPosition = handler.currentQueuePosition();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AccentScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: const Text('Up Next',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _queue.isEmpty
          ? Center(
              child: Text('Queue is empty',
                  style: TextStyle(color: Colors.white.withOpacity(0.5))),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _queue.length,
              onReorder: _handleReorder,
              proxyDecorator: (child, index, animation) {
                // Slight scale-up + shadow while a row is being dragged —
                // otherwise ReorderableListView's default proxy is nearly
                // indistinguishable from a resting row against this dark
                // background.
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final t = Curves.easeOut.transform(animation.value);
                    return Transform.scale(
                      scale: 1.0 + 0.02 * t,
                      child: Material(
                        color: Colors.transparent,
                        elevation: 8 * t,
                        shadowColor: Colors.black.withOpacity(0.4),
                        child: child,
                      ),
                    );
                  },
                );
              },
              itemBuilder: (context, index) {
                final track = _queue[index];
                final isCurrent = index == _currentPosition;

                return Dismissible(
                  key: ValueKey('${track.filePath}_$index'),
                  direction: isCurrent
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red.withOpacity(0.25),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child:
                        const Icon(Icons.delete_outline, color: Colors.white70),
                  ),
                  onDismissed: (_) => _handleRemove(index),
                  child: Container(
                    key: ValueKey('row_${track.filePath}_$index'),
                    color: isCurrent
                        ? accent.primary.withOpacity(0.12)
                        : Colors.transparent,
                    child: ListTile(
                      leading: isCurrent
                          ? Icon(Icons.graphic_eq,
                              color: accent.primary, size: 20)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 13),
                            ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? accent.primary : Colors.white,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        track.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12.5),
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: Icon(Icons.drag_handle,
                            color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    final handler = ref.read(audioHandlerProvider);
    handler.reorderQueue(oldIndex, newIndex);

    setState(() {
      // Optimistic local update so the row animates immediately rather
      // than waiting a frame for the handler's queue broadcast to round-
      // trip back through Riverpod.
      final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      final moved = _queue.removeAt(oldIndex);
      _queue.insert(adjustedNewIndex, moved);
      _currentPosition = handler.currentQueuePosition();
    });
  }

  void _handleRemove(int visualIndex) {
    final handler = ref.read(audioHandlerProvider);
    handler.removeFromQueueAt(visualIndex);

    setState(() {
      _queue.removeAt(visualIndex);
      _currentPosition = handler.currentQueuePosition();
    });
  }
}
