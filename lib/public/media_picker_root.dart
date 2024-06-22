import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../di/media_picker_factory.dart';
import '../widget/media_picker_widget.dart';

class MediaPickerRoot extends StatelessWidget {
  const MediaPickerRoot({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => buildMediaPickerBloc(),
        child: const MediaPickerWidget(),
      );
}
