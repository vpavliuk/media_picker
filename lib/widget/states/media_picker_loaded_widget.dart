import 'dart:io';

import 'package:flutter/material.dart';

import '../../bloc/media_picker_item_range.dart';

final class MediaPickerLoadedWidget extends StatefulWidget {
  final int itemCount;
  final Map<int, String> preparedThumbnails;
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
  static const int _columnCount = 5;
  MediaPickerItemRange _visibleRange = MediaPickerItemRange.empty;

  // use this one if the listItem's height is known
  // or width in case of a horizontal list
  void _onScroll() {
    double scrollOffset = _scrollController.offset;
    const itemHeight = 60.0;
    int firstVisibleItemIndex = scrollOffset < itemHeight
        ? 0
        : (scrollOffset / (itemHeight * _columnCount)).ceil();
    final newVisibleRange =
        MediaPickerItemRange(start: firstVisibleItemIndex, length: 75);
    if (newVisibleRange == _visibleRange) {
      return;
    }
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
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _columnCount, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 1),
        itemBuilder: (_, index) {
          final image = widget.preparedThumbnails[index];
          if (image == null) {
            return GridTile(child: Container(color: Colors.grey, child: Visibility(child: const CircularProgressIndicator(color: Colors.red,), visible: index % 10 == 0,),),);
          } else {
            return GridTile(
                child: Image.file(File(image), fit: BoxFit.cover));
          }
        },
        itemCount: widget.itemCount,
      );
      return ListView.separated(
        controller: _scrollController,
        itemCount: widget.itemCount,
        //itemExtent: 300.0,
        itemBuilder: (BuildContext context, int index) {
          final image = widget.preparedThumbnails[index];
          if (image == null) {
            return Container(color: Colors.grey, height: 300.0);
          } else {
            return SizedBox(
                height: 300.0,
                child: Image.file(File(image), fit: BoxFit.fitHeight));
          }
        },
        separatorBuilder: (_, __) =>
            const Divider(color: Colors.white, thickness: 20),
      );
    });
  }
}
