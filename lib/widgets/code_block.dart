import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' show highlight;
import 'package:highlight/highlight.dart' as hi;

/// flutter_markdown の syntaxHighlighter パラメータ用
class AppSyntaxHighlighter extends SyntaxHighlighter {
  AppSyntaxHighlighter({required this.brightness});

  final Brightness brightness;

  @override
  TextSpan format(String source) {
    final theme = brightness == Brightness.dark ? _darkTheme : _lightTheme;
    try {
      final result = highlight.parse(source, autoDetection: true);
      return TextSpan(
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.5,
          color: theme['_base']!.color,
        ),
        children: _convert(result.nodes ?? [], theme),
      );
    } catch (_) {
      return TextSpan(text: source);
    }
  }

  List<TextSpan> _convert(List<hi.Node> nodes, Map<String, TextStyle> theme) {
    final spans = <TextSpan>[];
    for (final node in nodes) {
      if (node.children != null && node.children!.isNotEmpty) {
        spans.add(TextSpan(
          style: theme[node.className],
          children: _convert(node.children!, theme),
        ));
      } else {
        spans.add(TextSpan(
          text: node.value,
          style: theme[node.className],
        ));
      }
    }
    return spans;
  }
}

const _lightTheme = <String, TextStyle>{
  '_base': TextStyle(color: Color(0xFF24292E)),
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

// GitHub Dark inspired palette so plain (unmatched) tokens stay legible on a
// dark code-block background — the light palette's near-black base color is
// otherwise invisible.
const _darkTheme = <String, TextStyle>{
  '_base': TextStyle(color: Color(0xFFC9D1D9)),
  'keyword': TextStyle(color: Color(0xFFFF7B72)),
  'built_in': TextStyle(color: Color(0xFF79C0FF)),
  'type': TextStyle(color: Color(0xFF79C0FF)),
  'literal': TextStyle(color: Color(0xFF79C0FF)),
  'number': TextStyle(color: Color(0xFF79C0FF)),
  'string': TextStyle(color: Color(0xFFA5D6FF)),
  'comment': TextStyle(color: Color(0xFF8B949E), fontStyle: FontStyle.italic),
  'doctag': TextStyle(color: Color(0xFF8B949E)),
  'title': TextStyle(color: Color(0xFFD2A8FF)),
  'function': TextStyle(color: Color(0xFFD2A8FF)),
  'class': TextStyle(color: Color(0xFFD2A8FF)),
  'symbol': TextStyle(color: Color(0xFF79C0FF)),
  'meta': TextStyle(color: Color(0xFF79C0FF)),
  'attr': TextStyle(color: Color(0xFF79C0FF)),
  'attribute': TextStyle(color: Color(0xFF79C0FF)),
  'params': TextStyle(color: Color(0xFFC9D1D9)),
  'subst': TextStyle(color: Color(0xFFC9D1D9)),
  'selector-tag': TextStyle(color: Color(0xFFFF7B72)),
  'selector-class': TextStyle(color: Color(0xFFD2A8FF)),
  'selector-id': TextStyle(color: Color(0xFF79C0FF)),
  'addition': TextStyle(color: Color(0xFF3FB950), backgroundColor: Color(0xFF033A16)),
  'deletion': TextStyle(color: Color(0xFFF85149), backgroundColor: Color(0xFF67060C)),
  'variable': TextStyle(color: Color(0xFFFFA657)),
  'template-variable': TextStyle(color: Color(0xFFFFA657)),
  'link': TextStyle(color: Color(0xFFA5D6FF), decoration: TextDecoration.underline),
  'name': TextStyle(color: Color(0xFF7EE787)),
  'tag': TextStyle(color: Color(0xFF7EE787)),
  'regexp': TextStyle(color: Color(0xFFA5D6FF)),
  'section': TextStyle(color: Color(0xFF79C0FF), fontWeight: FontWeight.bold),
};
