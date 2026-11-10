import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/estacionaya_theme.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final curve = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = curve;
    _scaleAnimation = Tween<double>(begin: 0.82, end: 1).animate(curve);
    _animationController.forward();

    _navigationTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EstacionaYaTokens.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_parking_rounded,
                    size: 62,
                    color: EstacionaYaTokens.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'EstacionaYa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu espacio, más cerca',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
