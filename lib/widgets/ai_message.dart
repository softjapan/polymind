import 'dart:convert';
import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chatgpt/constants.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AiMessage extends StatelessWidget {
  const AiMessage({
    super.key,
    required this.text,
    this.isStreaming = false,
    this.imageUrl,
    this.altText,
  });

  final String text;
  final bool isStreaming;
  final String? imageUrl;
  final String? altText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FcColors.aiBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    _ImageBubble(
                      imageUrl: imageUrl!,
                      caption: _captionText,
                      onTap: () => _openImageViewer(context),
                    )
                  else ...[
                    MarkdownBody(
                      data: text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: FcColors.black,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        code: TextStyle(
                          backgroundColor: FcColors.inputBg,
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: FcColors.inputBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (isStreaming) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 40,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: FcColors.accent,
                          backgroundColor: FcColors.border,
                        ),
                      ),
                    ],
                  ],
                  // Copy button for completed text messages
                  if (!isStreaming &&
                      (imageUrl == null || imageUrl!.isEmpty) &&
                      text.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: FcColors.gray,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  String? get _captionText {
    if (altText != null && altText!.trim().isNotEmpty) return altText!.trim();
    if (text.trim().isNotEmpty) return text.trim();
    return null;
  }

  Future<void> _openImageViewer(BuildContext context) async {
    final imageSrc = imageUrl;
    if (imageSrc == null || imageSrc.isEmpty) return;
    final caption = _captionText;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (dialogContext) => _ImageViewerDialog(
        imageUrl: imageSrc,
        caption: caption,
        onDownload: () => _downloadImage(messenger),
      ),
    );
  }

  Future<void> _downloadImage(ScaffoldMessengerState messenger) async {
    if (kIsWeb) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Download not supported on web.')),
      );
      return;
    }
    try {
      final bytes = await _loadImageBytes();
      final directory = await getApplicationDocumentsDirectory();
      final filename = 'ai_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = io.File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);
      messenger.showSnackBar(
        SnackBar(content: Text('Saved: ${file.path}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<Uint8List> _loadImageBytes() async {
    final imageSrc = imageUrl;
    if (imageSrc == null || imageSrc.isEmpty) {
      throw StateError('Image source is empty.');
    }
    if (imageSrc.startsWith('data:image')) return _decodeDataUri(imageSrc);
    final response = await http.get(Uri.parse(imageSrc));
    if (response.statusCode != 200) {
      throw StateError('Failed to download image data.');
    }
    return response.bodyBytes;
  }
}

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({
    required this.imageUrl,
    this.caption,
    this.onTap,
  });

  final String imageUrl;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildPreview(),
          ),
        ),
        if (caption != null && caption!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            caption!,
            style: TextStyle(
              color: FcColors.darkGray,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreview() {
    if (imageUrl.startsWith('data:image')) {
      final bytes = _decodeDataUri(imageUrl);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FcColors.inputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FcColors.inputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.broken_image, color: FcColors.gray),
      ),
    );
  }
}

class _ImageViewerDialog extends StatelessWidget {
  const _ImageViewerDialog({
    required this.imageUrl,
    required this.onDownload,
    this.caption,
  });

  final String imageUrl;
  final String? caption;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: _FullscreenImage(imageUrl: imageUrl),
              ),
            ),
            if (caption != null && caption!.isNotEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: 80,
                child: Text(
                  caption!,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Download',
                    icon: const Icon(Icons.download_outlined,
                        color: Colors.white),
                    onPressed: onDownload,
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  const _FullscreenImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image')) {
      final bytes = _decodeDataUri(imageUrl);
      return Center(child: Image.memory(bytes, fit: BoxFit.contain));
    }
    return Center(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        progressIndicatorBuilder: (context, url, p) =>
            CircularProgressIndicator(value: p.progress),
        errorWidget: (context, url, error) =>
            const Icon(Icons.broken_image, color: Colors.white70, size: 64),
      ),
    );
  }
}

Uint8List _decodeDataUri(String uri) {
  final commaIndex = uri.indexOf(',');
  final data = commaIndex != -1 ? uri.substring(commaIndex + 1) : uri;
  return base64Decode(data);
}
