import 'dart:io';
import 'package:flutter/services.dart';

bool _isTV = false;
bool get isAndroidTV => _isTV;

Future<void> initTVDetection() async {
  if (!Platform.isAndroid) return;
  try {
    const channel = MethodChannel('app/tv_detector');
    _isTV = await channel.invokeMethod<bool>('isTV') ?? false;
  } catch (_) {
    _isTV = false;
  }
}
