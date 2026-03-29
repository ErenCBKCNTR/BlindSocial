import 'package:flutter/material.dart';

class GlobalBackgroundWrapper extends StatelessWidget {
  final Widget child;

  const GlobalBackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/images/icon.png',
                width: MediaQuery.of(context).size.width * 0.4,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
