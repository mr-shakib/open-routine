import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search box with suggestions drawn from the local routine.
///
/// Suggestions come from what is actually in the routine, so a suggestion can
/// never lead to an empty result.
class RoutineSearchField extends ConsumerStatefulWidget {
  const RoutineSearchField({
    required this.hint,
    required this.initialValue,
    required this.suggestions,
    required this.onSubmit,
    super.key,
  });

  final String hint;
  final String initialValue;
  final Future<List<String>> Function(String query) suggestions;
  final ValueChanged<String> onSubmit;

  @override
  ConsumerState<RoutineSearchField> createState() => _RoutineSearchFieldState();
}

class _RoutineSearchFieldState extends ConsumerState<RoutineSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  final FocusNode _focus = FocusNode();
  List<String> _matches = const [];

  @override
  void initState() {
    super.initState();
    // Focusing a field that already holds a value should offer to replace it,
    // not append to it. Without this, tapping in and typing "60_C" over "66_B"
    // silently produces "66_B60_C".
    _focus.addListener(() {
      if (_focus.hasFocus && _controller.text.isNotEmpty) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void didUpdateWidget(RoutineSearchField old) {
    super.didUpdateWidget(old);
    // Keep in step when the value is changed from elsewhere, such as tapping a
    // recent chip.
    if (widget.initialValue != old.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
      setState(() => _matches = const []);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String value) async {
    final matches = value.trim().isEmpty
        ? const <String>[]
        : await widget.suggestions(value);
    if (mounted) setState(() => _matches = matches);
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _controller.text = trimmed;
    setState(() => _matches = const []);
    FocusScope.of(context).unfocus();
    widget.onSubmit(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear',
                      onPressed: () {
                        _controller.clear();
                        setState(() => _matches = const []);
                      },
                    ),
            ),
            onChanged: _onChanged,
            onSubmitted: _submit,
          ),
        ),
        if (_matches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final match in _matches)
                  ActionChip(
                    label: Text(match),
                    onPressed: () => _submit(match),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
