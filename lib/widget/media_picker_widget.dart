import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_picker/bloc/media_picker_state.dart';
import 'package:media_picker/widget/states/media_picker_loaded_widget.dart';
import 'package:media_picker/widget/states/media_picker_loading_widget.dart';

import '../bloc/media_picker_bloc.dart';
import '../bloc/media_picker_event.dart';

final class MediaPickerWidget extends StatefulWidget {
  const MediaPickerWidget({super.key});

  @override
  State<MediaPickerWidget> createState() => _MediaPickerWidgetState();
}

class _MediaPickerWidgetState extends State<MediaPickerWidget> {
  @override
  void initState() {
    super.initState();

    _dispatchEvent(const OnViewLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MediaPickerBloc, MediaPickerState>(
      builder: (BuildContext context, MediaPickerState state) {
        if (state is MediaPickerLoadingState) {
          return const MediaPickerLoadingWidget();
        } else if (state is MediaPickerLoadedState) {
          return MediaPickerLoadedWidget(
              itemCount: state.count,
              preparedThumbnails: state.preparedThumbnails,
              onVisibleItemRangeChanged: (range) {
                _dispatchEvent(MediaPickerVisibleItemsRangeDidChange(range));
              });
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  void _dispatchEvent(MediaPickerEvent event) =>
      BlocProvider.of<MediaPickerBloc>(context).add(event);
}
