import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' show highlight;
import 'package:highlight/highlight.dart' as hi;

/// flutter_markdown の syntaxHighlighter パラメータ用
class AppSyntaxHighlighter extends SyntaxHighlighter {
  @override
  TextSpan format(String source) {
    try {
      final result = highlight.parse(source, autoDetection: true);
      return TextSpan(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.5,
          color: Color(0xFF24292E),
        ),
        children: _convert(result.nodes ?? []),
      );
    } catch (_) {
      return TextSpan(text: source);
    }
  }

  List<TextSpan> _convert(List<hi.Node> nodes) {
    final spans = <TextSpan>[];
    for (final node in nodes) {
      if (node.children != null && node.children!.isNotEmpty) {
        spans.add(TextSpan(
          style: _theme[node.className],
          children: _convert(node.children!),
        ));
      } else {
        spans.add(TextSpan(
          text: node.value,
          style: _theme[node.className],
        ));
      }
    }
    return spans;
  }
}

const _theme = <String, TextStyle>{
  'keyword': TextStyle(color: Color(0xFFD73A49)),
  'built_in': TextStyle(color: Color(0xFF005CC5)),
  'type': TextStyle(color: Color(0xFF005CC5)),
  'literal': TextStyle(color: Color(0xFF005CC5)),
  'number': TextStyle(color: Color(0xFF005CC5)),
  'string': TextStyle(color: Color(0xFF032F62)),
  'comment': TextStyle(color: Color(0xFF6A737D), fontStyle: FontStyle.italic),
  'doctag': TextStyle(color: Color(0xFF6A737D)),
  'title': TextStyle(color: Color(0xFF6F42C1)),
  'function': TextStyle(color: Color(0xFF6F42C1)),
  'class': TextStyle(color: Color(0xFF6F42C1)),
  'symbol': TextStyle(color: Color(0xFF005CC5)),
  'meta': TextStyle(color: Color(0xFF005CC5)),
  'attr': TextStyle(color: Color(0xFF005CC5)),
  'attribute': TextStyle(color: Color(0xFF005CC5)),
  'params': TextStyle(color: Color(0xFF24292E)),
  'subst': TextStyle(color: Color(0xFF24292E)),
  'selector-tag': TextStyle(color: Color(0xFFD73A49)),
  'selector-class': TextStyle(color: Color(0xFF6F42C1)),
  'selector-id': TextStyle(color: Color(0xFF005CC5)),
  'addition': TextStyle(color: Color(0xFF22863A), backgroundColor: Color(0xFFF0FFF4)),
  'deletion': TextStyle(color: Color(0xFFB31D28), backgroundColor: Color(0xFFFEDBDB)),
  'variable': TextStyle(color: Color(0xFFE36209)),
  'template-variable': TextStyle(color: Color(0xFFE36209)),
  'link': TextStyle(color: Color(0xFF032F62), decoration: TextDecoration.underline),
  'name': TextStyle(color: Color(0xFF22863A)),
  'tag': TextStyle(color: Color(0xFF22863A)),
  'regexp': TextStyle(color: Color(0xFF032F62)),
  'section': TextStyle(color: Color(0xFF005CC5), fontWeight: FontWeight.bold),
};
