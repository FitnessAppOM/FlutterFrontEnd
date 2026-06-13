import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaBottomNavItem {
  const TaqaBottomNavItem({required this.assetPath, required this.index});

  final String assetPath;
  final int index;
}

class _TaqaBottomNavIconSpec {
  const _TaqaBottomNavIconSpec({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

class TaqaBottomNavBar extends StatelessWidget {
  const TaqaBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<TaqaBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _barHeight = 54;
  static const double _tapSize = 44;

  static const List<_TaqaBottomNavIconSpec> _specs = [
    _TaqaBottomNavIconSpec(left: 30, top: 15, width: 20, height: 20),
    _TaqaBottomNavIconSpec(left: 107, top: 14, width: 23, height: 23),
    _TaqaBottomNavIconSpec(left: 186, top: 15, width: 18, height: 20),
    _TaqaBottomNavIconSpec(left: 259, top: 14, width: 23, height: 23),
    _TaqaBottomNavIconSpec(left: 329, top: 17, width: 30, height: 18),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TaqaUiColors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 30,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: TaqaUiScale.h(_barHeight),
          child: Stack(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final spec = _specs[i % _specs.length];
              final selected = item.index == currentIndex;
              final centerX = spec.left + spec.width / 2;
              final centerY = spec.top + spec.height / 2;

              return Positioned(
                left: TaqaUiScale.w(centerX - _tapSize / 2),
                top: TaqaUiScale.h(centerY - _tapSize / 2),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(item.index),
                  child: SizedBox(
                    width: TaqaUiScale.w(_tapSize),
                    height: TaqaUiScale.h(_tapSize),
                    child: Center(
                      child: SvgPicture.asset(
                        item.assetPath,
                        width: TaqaUiScale.w(spec.width),
                        height: TaqaUiScale.h(spec.height),
                        colorFilter: ColorFilter.mode(
                          selected
                              ? TaqaUiColors.unnamedColor1c1d17
                              : TaqaUiColors.unnamedColor1c1d17.withValues(
                                  alpha: 0.4,
                                ),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
