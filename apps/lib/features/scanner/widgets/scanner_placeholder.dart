/// Scanner camera viewfinder placeholder widget (PRD section 7.5 B).
///
/// Simulates a live camera viewfinder with corner targets and scanning
/// laser line animation before hardware camera integration.
library;

import 'package:flutter/material.dart';

class ScannerPlaceholder extends StatefulWidget {
  const ScannerPlaceholder({super.key});

  @override
  State<ScannerPlaceholder> createState() => _ScannerPlaceholderState();
}

class _ScannerPlaceholderState extends State<ScannerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            children: [
              // Reticle Box
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white30, width: 2),
                ),
              ),

              // Corner accents
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.greenAccent, width: 4),
                      left: BorderSide(color: Colors.greenAccent, width: 4),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.greenAccent, width: 4),
                      right: BorderSide(color: Colors.greenAccent, width: 4),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.greenAccent, width: 4),
                      left: BorderSide(color: Colors.greenAccent, width: 4),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.greenAccent, width: 4),
                      right: BorderSide(color: Colors.greenAccent, width: 4),
                    ),
                  ),
                ),
              ),

              // Animated Scanning Laser Line
              AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return Align(
                    alignment: Alignment(0.0, (_animation.value * 2) - 1.0),
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Center helper watermark
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_2, size: 56, color: Colors.white24),
                    SizedBox(height: 8),
                    Text(
                      'Arahkan QR ke dalam kotak',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
