import 'package:flutter/material.dart';

final class MediaPickerLoadingWidget extends StatelessWidget {
  const MediaPickerLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
