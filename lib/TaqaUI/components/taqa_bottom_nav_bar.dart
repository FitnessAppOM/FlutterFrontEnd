import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TaqaBottomNavItem {
  const TaqaBottomNavItem({required this.assetPath, required this.index});

  final String assetPath;
  final int index;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
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
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final selected = item.index == currentIndex;
              return GestureDetector(
                onTap: () => onTap(item.index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SvgPicture.asset(
                    item.assetPath,
                    width: selected ? 30 : 26,
                    height: selected ? 30 : 26,
                    colorFilter: ColorFilter.mode(
                      selected
                          ? const Color(0xFF1C1D17)
                          : const Color(0x661C1D17),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
