import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../media/data/media_repository.dart';
import '../data/medical_profile_repository.dart';
import '../domain/medical_profile.dart';

enum _Source { camera, gallery, pdf }

/// PDFs bigger than this are almost never a lab report, and would make the
/// reader time out.
const _maxPdfBytes = 15 * 1024 * 1024;

/// Take/choose a photo or pick a PDF of a lab report, upload it, let MeMe
/// read it, then show every row for the user to review before anything is
/// saved. Returns the saved results (empty if the reader found nothing —
/// mock mode is honest about not being able to read), or null if the user
/// backed out at any point.
Future<List<LabResultData>?> runLabScanFlow(BuildContext context, WidgetRef ref) async {
  final source = await showModalBottomSheet<_Source>(
    context: context,
    backgroundColor: HealthColors.bgBase,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, _Source.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from library'),
            onTap: () => Navigator.pop(context, _Source.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Upload a PDF report'),
            subtitle: const Text('The file your lab or hospital sent you'),
            onTap: () => Navigator.pop(context, _Source.pdf),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final String mediaAssetId;
  if (source == _Source.pdf) {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null) return null;
    final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return null;
    if (bytes.length > _maxPdfBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("That PDF is over 15 MB — try a photo of the page instead.")),
        );
      }
      return null;
    }
    mediaAssetId = await ref.read(mediaRepositoryProvider).uploadDocument(bytes);
  } else {
    final picked = await ImagePicker().pickImage(
      source: source == _Source.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 90,
    );
    if (picked == null) return null;
    mediaAssetId = await ref.read(mediaRepositoryProvider).uploadPhoto(await picked.readAsBytes());
  }

  final repo = ref.read(medicalProfileRepositoryProvider);
  final scan = await repo.scanLabReport(mediaAssetId);
  if (scan.candidates.isEmpty) return const [];
  if (!context.mounted) return null;

  final reviewed = await showModalBottomSheet<_ReviewOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HealthColors.bgBase,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _LabReviewSheet(scan: scan),
  );
  if (reviewed == null) return null;

  final saved = await repo.saveLabResults(reviewed.kept, takenAt: reviewed.takenAt, mediaAssetId: scan.mediaAssetId);
  HapticFeedback.mediumImpact();
  return saved;
}

class _ReviewOutcome {
  const _ReviewOutcome({required this.kept, required this.takenAt});
  final List<LabCandidate> kept;
  final DateTime takenAt;
}

/// "Here's what MeMe read" — every row ticked by default, the report's date
/// pre-filled when it was printed on the page, nothing saved until Save.
class _LabReviewSheet extends StatefulWidget {
  const _LabReviewSheet({required this.scan});
  final LabScanResult scan;

  @override
  State<_LabReviewSheet> createState() => _LabReviewSheetState();
}

class _LabReviewSheetState extends State<_LabReviewSheet> {
  late final List<bool> _kept = List.filled(widget.scan.candidates.length, true);
  late DateTime _takenAt = widget.scan.reportDate ?? DateTime.now();

  int get _keptCount => _kept.where((k) => k).length;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _takenAt,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'When was the sample taken?',
    );
    if (picked != null) setState(() => _takenAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.scan.candidates;
    final detectedDate = widget.scan.reportDate != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        HealthSpacing.lg,
        HealthSpacing.md,
        HealthSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + HealthSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: HealthSpacing.md),
              decoration: BoxDecoration(color: HealthColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MemeMascot(state: MascotState.curious, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Here's what I read", style: HealthTypography.display(fontSize: 20)),
                    const SizedBox(height: 3),
                    Text(
                      'Untick anything that looks wrong. Nothing is saved until you tap Save.',
                      style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: HealthSpacing.md),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: HealthColors.surface,
                border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_outlined, size: 18, color: HealthColors.inkMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REPORT DATE', style: HealthTypography.label(fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(DateFormat('EEE, d MMM yyyy').format(_takenAt), style: HealthTypography.body(fontSize: 13.5)),
                      ],
                    ),
                  ),
                  Text(
                    detectedDate ? 'from the report · change' : 'tap to change',
                    style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: HealthSpacing.sm),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.42),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final c = candidates[i];
                final kept = _kept[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _kept[i] = !kept);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: kept ? HealthColors.surface : HealthColors.chipIdle,
                      border: Border.all(
                        color: kept ? HealthColors.accentPrimary.withValues(alpha: 0.35) : HealthColors.inkPrimary.withValues(alpha: 0.08),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          kept ? Icons.check_circle_rounded : Icons.circle_outlined,
                          size: 20,
                          color: kept ? HealthColors.accentPrimary : HealthColors.inkFaint,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.testName,
                                style: HealthTypography.body(fontSize: 13.5, color: kept ? HealthColors.inkPrimary : HealthColors.inkMuted),
                              ),
                              if (c.referenceRange != null)
                                Text('Range ${c.referenceRange}', style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint)),
                            ],
                          ),
                        ),
                        Text(
                          c.unit == null || c.unit!.isEmpty ? c.value : '${c.value} ${c.unit}',
                          style: HealthTypography.data(fontSize: 13.5, color: kept ? HealthColors.inkPrimary : HealthColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: HealthSpacing.md),
          Row(
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _keptCount == 0
                      ? null
                      : () => Navigator.pop(
                            context,
                            _ReviewOutcome(
                              kept: [for (var i = 0; i < candidates.length; i++) if (_kept[i]) candidates[i]],
                              takenAt: _takenAt,
                            ),
                          ),
                  child: Text('Save $_keptCount value${_keptCount == 1 ? '' : 's'}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
