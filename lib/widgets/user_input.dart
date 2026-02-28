import 'package:flutter/material.dart';
import 'package:flutter_chatgpt/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chatgpt/model/chatmodel.dart';

class UserInput extends ConsumerStatefulWidget {
  const UserInput({super.key, required this.chatcontroller});

  final TextEditingController chatcontroller;

  @override
  ConsumerState<UserInput> createState() => _UserInputState();
}

class _UserInputState extends ConsumerState<UserInput> {
  bool _hasText = false;

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

  void _send() {
    final text = widget.chatcontroller.text;
    if (text.trim().isEmpty) return;
    ref.read(chatProvider).sendChat(text);
    widget.chatcontroller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: FcColors.surface,
        border: Border(top: BorderSide(color: FcColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.chatcontroller,
                onFieldSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                style: const TextStyle(color: FcColors.black, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(color: FcColors.gray),
                  filled: true,
                  fillColor: FcColors.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                color: _hasText ? FcColors.accent : FcColors.inputBg,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _send,
                icon: Icon(
                  Icons.arrow_upward_rounded,
                  color: _hasText ? FcColors.white : FcColors.gray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
