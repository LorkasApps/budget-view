import 'package:image_picker/image_picker.dart';

import '../domain/receipt_image_source.dart';

/// Camera and gallery capture via `image_picker`.
///
/// Needs no Android permission: gallery picks go through the Photo Picker on
/// API 33+, the camera through `ACTION_IMAGE_CAPTURE`. Declaring `CAMERA` is
/// what would create a runtime request.
class ImagePickerReceiptImageSource implements ReceiptImageSource {
  ImagePickerReceiptImageSource([ImagePicker? picker])
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<CapturedReceiptImage?> pick(ScanSource source) async {
    final file = await _picker.pickImage(
      source: source == ScanSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (file == null) return null;

    return CapturedReceiptImage(
      bytes: await file.readAsBytes(),
      filename: source == ScanSource.camera ? '' : file.name,
    );
  }
}
