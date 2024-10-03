import '../bloc/media_picker_bloc.dart';
import '../repository/media_picker_repository.dart';
import '../repository/media_picker_concurrent_repository_impl.dart';

MediaPickerBloc buildMediaPickerBloc() =>
    MediaPickerBloc(repository: _buildMediaPickerRepository());

MediaPickerRepository _buildMediaPickerRepository() =>
    MediaPickerConcurrentRepositoryImpl();
