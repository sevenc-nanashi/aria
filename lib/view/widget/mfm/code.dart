import 'package:flutter/material.dart';
import 'package:flutter_highlighting/flutter_highlighting.dart';
import 'package:flutter_highlighting/themes/atelier-cave-light.dart';
import 'package:flutter_highlighting/themes/atom-one-dark.dart';
import 'package:highlighting/languages/all.dart';

import '../../../util/copy_text.dart';

class Code extends StatelessWidget {
  const Code({
    super.key,
    required this.code,
    this.language,
    this.inline = false,
    this.fontSize,
  });

  final String code;
  final String? language;
  final bool inline;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final languageId = allLanguages[language]?.id ?? 'javascript';

    return ClipRRect(
      borderRadius: BorderRadius.circular(4.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(4.0),
        onLongPress: () => copyToClipboard(context, code),
        child: HighlightView(
          code,
          languageId: languageId,
          theme: switch (Theme.of(context).brightness) {
            Brightness.light => atelierCaveLightTheme,
            Brightness.dark => atomOneDarkTheme,
          },
          padding: inline
              ? const EdgeInsets.symmetric(horizontal: 2.0)
              : const EdgeInsets.all(8.0),
          textStyle: TextStyle(
            fontSize: fontSize,
            fontFamilyFallback: const [
              'Consolas',
              'Monaco',
              'Andale Mono',
              'Ubuntu Mono',
              'monospace',
            ],
          ),
        ),
      ),
    );
  }
}
