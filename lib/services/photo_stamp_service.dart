// photo_stamp_service.dart
// Ported from the Vehga camera app's WatermarkService — keep visuals in sync.
// Composites the Vehga logo (bottom-left) and date/time + address
// (bottom-right) onto a captured photo, and letterboxes the image to a 4:3
// canvas (no cropping — every captured pixel is kept).

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import 'location_service.dart';

class PhotoStampService {
  static ui.Image? _logo;

  static const double _maxLongSide = 1920;

  static Future<ui.Image> _loadLogo() async {
    if (_logo != null) return _logo!;
    final data = await rootBundle.load('assets/vehga-logo.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    _logo = (await codec.getNextFrame()).image;
    return _logo!;
  }

  /// Watermarks [photoBytes] (logo + timestamp + address) and pads the result
  /// to a 4:3 canvas (3:4 for portrait shots) without cropping. Pass a null
  /// [location] to stamp date/time only. Returns JPEG bytes.
  static Future<Uint8List> apply({
    required Uint8List photoBytes,
    required WatermarkLocation? location,
    required DateTime timestamp,
  }) async {
    final logo = await _loadLogo();

    // Decode, capping the long side so uploads stay small and fast.
    final rawCodec = await ui.instantiateImageCodec(photoBytes);
    final rawFrame = await rawCodec.getNextFrame();
    final raw = rawFrame.image;

    final longSide =
        raw.width > raw.height ? raw.width.toDouble() : raw.height.toDouble();
    final scale = longSide > _maxLongSide ? _maxLongSide / longSide : 1.0;
    final width = (raw.width * scale).round();
    final height = (raw.height * scale).round();

    // 4:3 letterbox: grow the canvas (never shrink the image) until the
    // aspect ratio is 4:3 landscape or 3:4 portrait, image centered on black.
    final targetRatio = width >= height ? 4 / 3 : 3 / 4;
    int canvasWidth = width;
    int canvasHeight = height;
    if (width / height > targetRatio) {
      canvasHeight = (width / targetRatio).round();
    } else if (width / height < targetRatio) {
      canvasWidth = (height * targetRatio).round();
    }
    final dx = (canvasWidth - width) / 2;
    final dy = (canvasHeight - height) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
      Paint()..color = Colors.black,
    );
    canvas.drawImageRect(
      raw,
      Rect.fromLTWH(0, 0, raw.width.toDouble(), raw.height.toDouble()),
      Rect.fromLTWH(dx, dy, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );

    final pad = canvasWidth * 0.02;
    _drawStampText(canvas, canvasWidth, canvasHeight, pad, location, timestamp);
    _drawLogo(canvas, logo, canvasWidth, canvasHeight, pad);

    final picture = recorder.endRecording();
    final composed = await picture.toImage(canvasWidth, canvasHeight);
    final rgba = await composed.toByteData(format: ui.ImageByteFormat.rawRgba);

    raw.dispose();
    composed.dispose();

    // JPEG-encode off the UI thread.
    return compute(_encodeJpeg, _EncodeJob(
      width: canvasWidth,
      height: canvasHeight,
      rgba: rgba!.buffer.asUint8List(),
    ));
  }

  static TextPainter _buildStampPainter(
    double width,
    WatermarkLocation? location,
    DateTime timestamp,
  ) {
    final dateLine = DateFormat('MMM d, yyyy hh:mm:ss a').format(timestamp);
    final baseSize = width * 0.026;

    final shadows = [
      for (final dx in [-1.5, 1.5])
        for (final dy in [-1.5, 1.5])
          Shadow(
              offset: Offset(dx, dy),
              blurRadius: 2,
              color: Colors.black.withOpacity(0.85)),
    ];

    final painter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.right,
      text: TextSpan(
        children: [
          TextSpan(
            text: dateLine,
            style: TextStyle(
              color: Colors.white,
              fontSize: baseSize * 1.15,
              fontWeight: FontWeight.w700,
              height: 1.35,
              shadows: shadows,
            ),
          ),
          if (location != null)
            TextSpan(
              text: '\n${location.lines.join('\n')}',
              style: TextStyle(
                color: Colors.white,
                fontSize: baseSize,
                fontWeight: FontWeight.w600,
                height: 1.35,
                shadows: shadows,
              ),
            ),
        ],
      ),
    );

    painter.layout(maxWidth: width * 0.75);
    return painter;
  }

  static void _drawStampText(
    Canvas canvas,
    int width,
    int height,
    double pad,
    WatermarkLocation? location,
    DateTime timestamp,
  ) {
    final painter = _buildStampPainter(width.toDouble(), location, timestamp);
    painter.paint(canvas,
        Offset(width - painter.width - pad, height - painter.height - pad));
  }

  static void _paintLogoWithGlow(Canvas canvas, ui.Image logo, Rect dest) {
    final src =
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble());

    // White glow behind the logo keeps it visible on dark photos
    // without drawing an opaque box over the image.
    final glow = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcATop)
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6);
    canvas.drawImageRect(logo, src, dest, glow);
    canvas.drawImageRect(logo, src, dest, glow);

    canvas.drawImageRect(
        logo, src, dest, Paint()..filterQuality = FilterQuality.medium);
  }

  static void _drawLogo(
      Canvas canvas, ui.Image logo, int width, int height, double pad) {
    final logoWidth = width * 0.20;
    final logoHeight = logoWidth * logo.height / logo.width;
    _paintLogoWithGlow(canvas, logo,
        Rect.fromLTWH(pad, height - logoHeight - pad, logoWidth, logoHeight));
  }
}

class _EncodeJob {
  final int width;
  final int height;
  final Uint8List rgba;
  _EncodeJob({required this.width, required this.height, required this.rgba});
}

Uint8List _encodeJpeg(_EncodeJob job) {
  final image = img.Image.fromBytes(
    width: job.width,
    height: job.height,
    bytes: job.rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: 90);
}
