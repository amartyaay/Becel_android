import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/local_store.dart';

Future<void> showCheckInSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) => const CheckInSheet(),
  );
}

class CheckInSheet extends StatefulWidget {
  const CheckInSheet({super.key});

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  final _store = LocalStore.instance;
  final _note = TextEditingController();
  String? _tag;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = _store.log.checkInFor(DateTime.now());
    _tag = existing?.tags.isEmpty == true ? null : existing?.tags.first;
    _note.text = existing?.note ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_tag == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    final saved = await _store.saveCheckIn(
      day: DateTime.now(),
      tags: {_tag!},
      note: _note.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved for this session only — device storage failed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
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
            const Text('Morning check-in', style: AppType.sectionTitle),
            const SizedBox(height: 6),
            const Text(
              'Optional context for today’s suggestion. Stored on this phone '
              'only and never uploaded.',
              style: AppType.caption,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in checkInTagLabels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _tag == entry.key,
                    onSelected: (selected) =>
                        setState(() => _tag = selected ? entry.key : null),
                    showCheckmark: false,
                    labelStyle: AppType.caption.copyWith(
                      color: _tag == entry.key
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedColor: AppColors.teal.withValues(alpha: 0.18),
                    backgroundColor: AppColors.surfaceHigh,
                    side: BorderSide(
                      color: _tag == entry.key
                          ? AppColors.teal.withValues(alpha: 0.55)
                          : AppColors.border,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLength: 140,
              maxLines: 2,
              style: AppType.body,
              decoration: InputDecoration(
                hintText: 'Optional note — travel, alcohol, late meal…',
                hintStyle: AppType.caption,
                counterStyle: AppType.caption.copyWith(fontSize: 10),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_saving ? 'Saving…' : 'Save check-in'),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(
                  'Skip for today',
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
