import 'package:flutter/widgets.dart';

import '../tokens/drivon_spacing.dart';

/// Centers [child] and caps its width so phone layouts don't stretch across
/// tablets or landscape screens. Scroll views inside still scroll full height.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    required this.child,
    this.maxWidth = DrivonSpacing.contentMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
