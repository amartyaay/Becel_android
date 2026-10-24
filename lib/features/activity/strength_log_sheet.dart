import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/local_store.dart';
import '../../widgets/kit.dart';

Future<bool> showStrengthLogSheet(BuildContext context) async {
  final logged = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) => const StrengthLogSheet(),
  );
  return logged ?? false;
}

class StrengthLogSheet extends StatefulWidget {
  const StrengthLogSheet({super.key});

  @override
  State<StrengthLogSheet> createState() => _StrengthLogSheetState();
}

class _StrengthLogSheetState extends State<StrengthLogSheet> {
  bool _saving = false;

  Future<void> _log() async {
    setState(() => _saving = true);
    final saved = await LocalStore.instance.addStrengthDay(DateTime.now());
    if (!mounted) return;
    Navigator.of(context).pop(true);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged for this session only — storage failed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigher,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const IconChip(
                  icon: Icons.fitness_center_rounded,
                  color: AppColors.orange,
                  size: 44,
                  iconSize: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Log a strength day',
                    style: AppType.sectionTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Heart rate cannot reliably count strength work, so Becel asks '
              'instead. Bodyweight, bands, or weights all count.',
              style: AppType.body,
            ),
            const SizedBox(height: 10),
            const SourceLine(
              text:
                  'Manual entry · stored on this phone only · not written to '
                  'Health Connect',
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _saving ? null : _log,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(_saving ? 'Saving…' : 'I did strength today'),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(
                  'Cancel',
                  style: AppType.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
