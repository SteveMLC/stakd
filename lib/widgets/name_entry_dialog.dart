import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Dialog for entering/changing player display name
class NameEntryDialog extends StatefulWidget {
  final String? currentName;
  final bool isFirstTime;

  const NameEntryDialog({
    super.key,
    this.currentName,
    this.isFirstTime = false,
  });

  @override
  State<NameEntryDialog> createState() => _NameEntryDialogState();
}

class _NameEntryDialogState extends State<NameEntryDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() => _errorText = 'Please enter a name');
      return;
    }

    if (name.length < 2) {
      setState(() => _errorText = 'Name must be at least 2 characters');
      return;
    }

    if (name.length > 20) {
      setState(() => _errorText = 'Name must be 20 characters or less');
      return;
    }

    // Check for inappropriate content (basic filter)
    if (_containsInappropriate(name)) {
      setState(() => _errorText = 'Please choose a different name');
      return;
    }

    Navigator.of(context).pop(name);
  }

  bool _containsInappropriate(String name) {
    final lower = name.toLowerCase();
    final badWords = ['admin', 'moderator', 'staff', 'official'];
    return badWords.any((word) => lower.contains(word));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: GameColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: GameColors.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: GameColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isFirstTime
                            ? 'Welcome to Leaderboards!'
                            : 'Change Display Name',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isFirstTime
                            ? 'Choose a name to show on the leaderboards'
                            : 'Your name will update on all leaderboards',
                        style: const TextStyle(
                          fontSize: 12,
                          color: GameColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            // Input field
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 20,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: TextStyle(color: GameColors.textMuted),
                errorText: _errorText,
                filled: true,
                fillColor: GameColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: GameColors.accent,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: GameColors.errorGlow,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                counterStyle: TextStyle(color: GameColors.textMuted),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!widget.isFirstTime)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: GameColors.textMuted),
                    ),
                  ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.accent,
                    foregroundColor: GameColors.text,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(widget.isFirstTime ? 'Let\'s Go!' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows name entry dialog and returns the entered name (or null if cancelled)
Future<String?> showNameEntryDialog(
  BuildContext context, {
  String? currentName,
  bool isFirstTime = false,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: !isFirstTime,
    builder: (context) => NameEntryDialog(
      currentName: currentName,
      isFirstTime: isFirstTime,
    ),
  );
}
