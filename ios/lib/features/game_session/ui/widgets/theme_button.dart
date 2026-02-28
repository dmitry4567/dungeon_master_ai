import 'package:flutter/material.dart';

class ThemeButton extends StatelessWidget {
  const ThemeButton({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  icon,
                  color: const Color(0xFFD4AF37),
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      );
}
