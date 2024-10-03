import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../bloc/media_picker_item_range.dart';

final class MediaPickerLoadedWidget extends StatefulWidget {
  final int itemCount;
  final Map<int, Uint8List> preparedThumbnails;
  final ValueChanged<MediaPickerItemRange> onVisibleItemRangeChanged;

  const MediaPickerLoadedWidget({
    super.key,
    required this.itemCount,
    required this.preparedThumbnails,
    required this.onVisibleItemRangeChanged,
  });

  @override
  State<MediaPickerLoadedWidget> createState() => _MediaPickerLoadedWidget();
}

class _MediaPickerLoadedWidget extends State<MediaPickerLoadedWidget> {
  late ScrollController _scrollController;
  double _width = 0.0;
  double _height = 0.0;
  static const int _columnCount = 4;
  MediaPickerItemRange _visibleRange = MediaPickerItemRange.empty;

  // use this one if the listItem's height is known
  // or width in case of a horizontal list
  void _onScroll() {
    double scrollOffset = _scrollController.offset;
    const itemHeight = 94.25; // Figure out correct height
    int firstVisibleItemIndex = scrollOffset < itemHeight
        ? 0
        : (scrollOffset / itemHeight).floor() * _columnCount;
    final newVisibleRange =
        MediaPickerItemRange(start: firstVisibleItemIndex, length: 32);
    if (newVisibleRange == _visibleRange) {
      return;
    }
    print("Computed range: ${newVisibleRange.toString()}");
    _visibleRange = newVisibleRange;
    widget.onVisibleItemRangeChanged(newVisibleRange);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.removeListener(_onScroll);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _width = constraints.maxWidth;
      _height = constraints.maxHeight;
      return GridView.builder(
        controller: _scrollController,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columnCount,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        cacheExtent: 3000.0,
        itemBuilder: (_, index) {
          final image = widget.preparedThumbnails[index];
          if (image == null) {
            return Container(
              color: Colors.grey,
              child: Text(
                index.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            );
          } else {
            return GridTile(
              header: Text(index.toString(),
                  style: const TextStyle(color: Colors.white)),
              child: Image.memory(
                image,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            );
          }
        },
        itemCount: widget.itemCount,
      );
    });
  }
}
