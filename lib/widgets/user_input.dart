import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:polymind/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polymind/model/chatmodel.dart';
import 'package:uuid/uuid.dart';

class UserInput extends ConsumerStatefulWidget {
  const UserInput({super.key, required this.chatcontroller});

  final TextEditingController chatcontroller;

  @override
  ConsumerState<UserInput> createState() => _UserInputState();
}

class _UserInputState extends ConsumerState<UserInput> {
  bool _hasText = false;
  String? _attachedImagePath;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    widget.chatcontroller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.chatcontroller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.chatcontroller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = io.Directory(p.join(docsDir.path, 'chat_images'));
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
    final ext = p.extension(picked.path).isNotEmpty
        ? p.extension(picked.path)
        : '.jpg';
    final savedPath = p.join(imagesDir.path, '${_uuid.v4()}$ext');
    await io.File(picked.path).copy(savedPath);

    if (!mounted) return;
    setState(() => _attachedImagePath = savedPath);
  }

  void _showAttachOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Photos'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeAttachedImage() {
    setState(() => _attachedImagePath = null);
  }

  void _send() {
    final text = widget.chatcontroller.text;
    if (text.trim().isEmpty && _attachedImagePath == null) return;
    ref.read(chatProvider).sendChat(text, imagePath: _attachedImagePath);
    widget.chatcontroller.clear();
    setState(() => _attachedImagePath = null);
  }

  void _stop() {
    ref.read(chatProvider).stopGenerating();
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = ref.watch(
      chatProvider.select((model) => model.isGenerating),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_attachedImagePath != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        io.File(_attachedImagePath!),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: _removeAttachedImage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.colors.darkGray,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Attach image',
                  onPressed: _showAttachOptions,
                  icon: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: context.colors.gray,
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: widget.chatcontroller,
                    onFieldSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    style: TextStyle(color: context.colors.black, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: TextStyle(color: context.colors.gray),
                      filled: true,
                      fillColor: context.colors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isGenerating || _hasText || _attachedImagePath != null
                        ? context.colors.accent
                        : context.colors.inputBg,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: isGenerating ? _stop : _send,
                    icon: Icon(
                      isGenerating
                          ? Icons.stop_rounded
                          : Icons.arrow_upward_rounded,
                      color:
                          isGenerating || _hasText || _attachedImagePath != null
                              ? context.colors.white
                              : context.colors.gray,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
