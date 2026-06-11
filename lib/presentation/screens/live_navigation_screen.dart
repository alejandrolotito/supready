import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supready/core/theme/app_theme.dart';

class LiveNavigationScreen extends StatefulWidget {
  const LiveNavigationScreen({Key? key}) : super(key: key);

  @override
  State<LiveNavigationScreen> createState() => _LiveNavigationScreenState();
}

class _LiveNavigationScreenState extends State<LiveNavigationScreen> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBright,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppTheme.secondary, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text('GPS Activo (Alta Fidelidad)', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('VELOCIDAD ACTUAL', style: TextStyle(color: AppTheme.secondary, fontSize: 16, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    RichText(
                      text: const TextSpan(
                        text: '5.4 ',
                        style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: AppTheme.primary, fontFamily: 'Inter'),
                        children: [
                          TextSpan(text: 'km/h', style: TextStyle(fontSize: 24, fontWeight: FontWeight.normal, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  const Text('Distancia', style: TextStyle(color: AppTheme.secondary)),
                                  const SizedBox(height: 8),
                                  RichText(
                                    text: const TextSpan(
                                      text: '2.1 ',
                                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Inter'),
                                      children: [
                                        TextSpan(text: 'km', style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  const Text('Tiempo', style: TextStyle(color: AppTheme.secondary)),
                                  const SizedBox(height: 8),
                                  Text(_formatTime(_seconds), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surfaceBright, foregroundColor: Colors.white),
                      child: const Text('PAUSAR'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFffb4ab), foregroundColor: const Color(0xFF690005)),
                      child: const Text('FINALIZAR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
