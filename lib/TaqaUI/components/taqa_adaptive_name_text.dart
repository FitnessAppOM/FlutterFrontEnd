import 'package:flutter/material.dart';

import 'taqa_marquee_text.dart';

class TaqaAdaptiveNameText extends StatelessWidget {
  const TaqaAdaptiveNameText({
    super.key,
    required this.welcomeText,
    required this.style,
    this.greetingText,
    this.userNameText,
  });

  final String welcomeText;
  final String? greetingText;
  final String? userNameText;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final greeting = greetingText?.trim();
    final userName = userNameText?.trim();
    if (userName != null &&
        userName.isNotEmpty &&
        (greeting == null || greeting.isEmpty)) {
      return TaqaMarqueeText(text: userName, style: style);
    }
    if (greeting == null ||
        greeting.isEmpty ||
        userName == null ||
        userName.isEmpty) {
      return Text(
        welcomeText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        style: style,
      );
    }

    // Keep the greeting fixed and scroll only an overflowing name in the
    // remaining horizontal space.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$greeting ',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        Expanded(
          child: TaqaMarqueeText(text: userName, style: style),
        ),
      ],
    );
  }
}
