import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../media/data/media_repository.dart';
import '../data/medical_profile_repository.dart';
import '../domain/medical_profile.dart';

/// Take/choose a photo of a lab report, upload it, and run OCR against it.
/// Returns the extracted results (possibly empty — mock mode is honest
/// about not being able to read the photo), or null if the user cancelled
/// before picking anything.
Future<List<LabResultData>?> runLabScanFlow(BuildContext context, WidgetRef ref) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from library'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final picked = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 90);
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  final mediaAssetId = await ref.read(mediaRepositoryProvider).uploadPhoto(bytes);
  return ref.read(medicalProfileRepositoryProvider).scanLabReport(mediaAssetId);
}
