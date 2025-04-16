// lib/services/share_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';

class ShareService {
  // Singleton pattern
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  // Share text only
  Future<void> shareText({required String text, String? subject}) async {
    try {
      await Share.share(text, subject: subject);
    } catch (e) {
      print('Error sharing text: $e');
    }
  }

  // Share image and text
  Future<void> shareImageAndText({
    required Uint8List imageBytes,
    required String text,
    String? subject,
  }) async {
    try {
      // Save image to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/share_image.png');
      await file.writeAsBytes(imageBytes);

      final files = <XFile>[XFile(file.path)];
      await Share.shareXFiles(files, text: text, subject: subject);
    } catch (e) {
      print('Error sharing image: $e');
    }
  }

  // 安全なウィジェットキャプチャ方法
  Future<Uint8List?> captureWidget(GlobalKey widgetKey) async {
    try {
      // コンテキストとRenderObjectの安全なチェック
      if (widgetKey.currentContext == null) {
        print('Context is null, cannot capture widget');
        return null;
      }

      final renderObject = widgetKey.currentContext!.findRenderObject();
      if (renderObject == null) {
        print('RenderObject is null, cannot capture widget');
        return null;
      }

      // RenderRepaintBoundaryであることを確認
      if (renderObject is! RenderRepaintBoundary) {
        print(
          'RenderObject is not a RenderRepaintBoundary. Make sure to wrap your widget with RepaintBoundary',
        );
        // フォールバックとして代替のスクリーンショット方法を提供
        return await _createPlaceholderImage();
      }

      // キャプチャ
      final boundary = renderObject as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        print('Failed to get byte data from image');
        return await _createPlaceholderImage();
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      print('Error capturing widget: $e');
      // エラー時は代替イメージを生成
      return await _createPlaceholderImage();
    }
  }

  // 代替の画像を生成（キャプチャ失敗時のフォールバック）
  Future<Uint8List?> _createPlaceholderImage() async {
    try {
      // シンプルな代替画像を生成
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 600);

      // 背景を描画
      final background = Paint()..color = Color(0xFFEDE7F6);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), background);

      // テキストを描画
      final paragraphBuilder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 24),
            )
            ..pushStyle(ui.TextStyle(color: Color(0xFF673AB7)))
            ..addText('エホミル\n大人も楽しめる絵本アプリ');
      final paragraph = paragraphBuilder.build();
      paragraph.layout(ui.ParagraphConstraints(width: size.width));
      canvas.drawParagraph(paragraph, Offset(0, size.height / 2 - 50));

      // 画像を生成
      final picture = recorder.endRecording();
      final img = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      print('Error creating placeholder image: $e');
      return null;
    }
  }

  // Generate share content based on the selected platform
  String generateShareText(String platform) {
    final String appUrl = 'https://ehomil.app/download';
    final String baseText =
        '大人も楽しめる絵本アプリ「エホミル」で素敵な絵本を見つけました！\n\nダウンロードはこちらから：$appUrl';

    // Customize text for different platforms if needed
    switch (platform) {
      case 'twitter':
        return '$baseText\n\n#エホミル #絵本 #大人絵本';
      case 'instagram':
        return '$baseText\n\n#エホミル #絵本 #大人絵本 #読書';
      case 'facebook':
        return '$baseText\n\n大人も子供も楽しめる絵本アプリです。';
      case 'line':
        return baseText;
      default:
        return baseText;
    }
  }

  // Share to specific platform with safe navigation
  Future<void> shareToSpecificPlatform({
    required String platform,
    Uint8List? imageBytes,
    String? customText,
  }) async {
    // メッセージテキスト
    final String shareText = customText ?? generateShareText(platform);
    // 件名
    final String shareSubject = '「エホミル」で見つけた素敵な絵本';

    try {
      if (imageBytes != null) {
        // 画像とテキストを共有
        await shareImageAndText(
          imageBytes: imageBytes,
          text: shareText,
          subject: shareSubject,
        );
      } else {
        // テキストのみ共有
        await this.shareText(text: shareText, subject: shareSubject);
      }
    } catch (e) {
      print('Error sharing to $platform: $e');
    }
  }
}
