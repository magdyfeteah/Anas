import 'dart:math';

import 'package:flutter/material.dart';

class AnimatedRecordingCircle extends StatefulWidget {
  final bool isRecording;

  const AnimatedRecordingCircle({super.key, this.isRecording = false});

  @override
  State<AnimatedRecordingCircle> createState() =>
      _AnimatedRecordingCircleState();
}

class _AnimatedRecordingCircleState extends State<AnimatedRecordingCircle>
    with TickerProviderStateMixin {
  late AnimationController _morphController;
  late AnimationController _rotationController;

  late Animation<BorderRadiusGeometry?> _borderRadiusAnimation;
  late Animation<double> _widthAnimation;
  late Animation<double> _heightAnimation;

  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700), // Duration for one morph
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _borderRadiusAnimation =
        BorderRadiusTween(
          begin: BorderRadius.circular(100.0),
          end: BorderRadius.circular(70.0),
        ).animate(
          CurvedAnimation(parent: _morphController, curve: Curves.easeInOut),
        );

    _widthAnimation = Tween<double>(begin: 200, end: 170).animate(
      CurvedAnimation(parent: _morphController, curve: Curves.easeInOut),
    );

    _heightAnimation = Tween<double>(begin: 200, end: 200).animate(
      CurvedAnimation(parent: _morphController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
    if (widget.isRecording) {
      _startAnimations();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedRecordingCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  void _startAnimations() {
    _morphController.forward();
    _rotationController.repeat();
  }

  void _stopAnimations() {
    _morphController.reverse();
    _rotationController.stop();
  }

  @override
  void dispose() {
    _morphController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_morphController, _rotationController]),
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value, // Apply rotation
          child: Container(
            width: _widthAnimation.value,
            height: _heightAnimation.value,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: _borderRadiusAnimation.value,
            ),
          ),
        );
      },
    );
  }
}
