import 'package:flutter_test/flutter_test.dart';
import 'package:media_picker/bloc/media_picker_bloc.dart';
import 'package:media_picker/bloc/media_picker_event.dart';
import 'package:media_picker/bloc/media_picker_item_range.dart';
import 'package:media_picker/bloc/media_picker_state.dart';
import 'package:media_picker/repository/media_picker_repository.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late MediaPickerBloc sut;
  late MediaPickerRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(MediaPickerItemRange.empty);
  });

  setUp(() {
    mockRepository = MediaPickerRepositoryMock();
    sut = MediaPickerBloc(repository: mockRepository);
  });

  test('Initial state', () {
    expect(sut.state, const MediaPickerLoadingState());
  });

  test('On view loaded, when the album stream is empty', () async {
    // Arrange
    when(() => mockRepository.masterAlbumStream)
        .thenAnswer((_) => const Stream.empty());

    // Act
    sut.add(const OnViewLoaded());

    // Assert
    sut.stream.listen((state) {
      // Any emitted state is treated as failure
      expect(true, false, reason: 'Bloc emitted a state unexpectedly: $state');
    });
    // Give the bloc a chance to emit some states.
    await Future.delayed(const Duration(milliseconds: 20));

    verifyNever(
      () => mockRepository.requestThumbnails(
          range: any(named: 'range'), handleInReverse: false),
    );
  });

  test('On view loaded, when the album stream emits a single value', () async {
    // Arrange
    const albumItemCount = 12;
    when(() => mockRepository.masterAlbumStream).thenAnswer((_) => Stream.value(
          const MediaPickerAlbumInfo(
            itemCount: albumItemCount,
            thumbnails: {},
          ),
        ));
    const expectedState = MediaPickerLoadedState(
      count: albumItemCount,
      preparedThumbnails: {},
    );

    // Act
    sut.add(const OnViewLoaded());

    // Assert
    await expectLater(sut.stream, emits(expectedState));
    verifyNever(
      () => mockRepository.requestThumbnails(
        range: any(named: 'range'),
        handleInReverse: false,
      ),
    );
  });
}

final class MediaPickerRepositoryMock extends Mock
    implements MediaPickerRepository {}
