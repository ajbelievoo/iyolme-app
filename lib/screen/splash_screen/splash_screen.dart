import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/screen/splash_screen/splash_screen_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<SplashScreenController>()) {
      Get.find<SplashScreenController>();
    } else {
      Get.put(SplashScreenController());
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFFFFF),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FAFF),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 220,
            child: Image(
              image: AssetImage('assets/icons/app_splash_opt.png'),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
