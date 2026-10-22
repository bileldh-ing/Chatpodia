import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/liquid_glass.dart';

/// "Type a message..." glass pill + waveform (voice) + mint send button.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    this.onVoice,
    this.onStop,
    this.busy = false,
    this.controller,
    this.focusNode,
    this.allowAttachments = true,
    this.picker,
  });

  final bool allowAttachments;

  /// Injectable for tests.
  final Future<String?> Function()? picker;

  /// Called with the text and any attached image file paths.
  final void Function(String text, List<String> images) onSend;
  final VoidCallback? onVoice;
  final VoidCallback? onStop;
  final bool busy;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  late final TextEditingController _c = widget.controller ?? TextEditingController();
  bool _hasText = false;
  final List<String> _images = [];

  Future<void> _attach() async {
    if (_images.length >= 4) return;
    final path = widget.picker != null
        ? await widget.picker!()
        : (await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85))?.path;
    if (path != null && mounted) setState(() => _images.add(path));
  }

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      final v = _c.text.trim().isNotEmpty;
      if (v != _hasText) setState(() => _hasText = v);
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _c.text.trim();
    if (t.isEmpty && _images.isEmpty) return;
    widget.onSend(t, List.of(_images));
    _c.clear();
    setState(() => _images.clear());
  }

  bool get _canSend => _hasText || _images.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: _images.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Stack(clipBehavior: Clip.none, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(File(_images[i]), width: 64, height: 64, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: -6,
                          top: -6,
                          child: GlassIconButton(
                            icon: Icons.close_rounded,
                            size: 22,
                            iconSize: 12,
                            tooltip: 'Remove attachment',
                            onTap: () => setState(() => _images.removeAt(i)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
        ),
        _row(),
      ],
    );
  }

  Widget _row() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: LiquidGlass(
            borderRadius: BorderRadius.circular(23),
            tint: const Color(0x14FFFFFF),
            padding: const EdgeInsets.only(left: 18, right: 6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _c,
                      focusNode: widget.focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      style: AppText.body.copyWith(fontSize: 14),
                      cursorColor: AppColors.mint,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                        hintText: 'Type a message...',
                        hintStyle: AppText.body.copyWith(color: AppColors.textTertiary, fontSize: 14),
                      ),
                    ),
                  ),
                  if (widget.allowAttachments)
                    Semantics(
                      button: true,
                      label: 'Attach image',
                      child: Pressable(
                        onTap: _attach,
                        child: const Padding(
                          padding: EdgeInsets.all(9),
                          child: Icon(Icons.add_photo_alternate_outlined, size: 20, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  Pressable(
                    onTap: widget.onVoice,
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(Icons.graphic_eq_rounded, size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
          child: widget.busy
              ? AccentCircleButton(
                  key: const ValueKey('stop'), icon: Icons.stop_rounded, onTap: widget.onStop, size: 46)
              : AccentCircleButton(
                  key: const ValueKey('send'),
                  icon: Icons.send_outlined,
                  iconSize: 19,
                  size: 46,
                  onTap: _canSend ? _submit : widget.onVoice,
                ),
        ),
      ],
    );
  }
}
