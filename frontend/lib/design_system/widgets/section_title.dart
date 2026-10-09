import 'package:flutter/material.dart';

/// A heading above a group of content, e.g. "Fill-ups". Reads the theme
/// where it is placed, so it turns dark on a paper sheet.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
