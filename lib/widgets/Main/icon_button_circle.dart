import 'package:flutter/material.dart';

class IconButtonCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const IconButtonCircle({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}