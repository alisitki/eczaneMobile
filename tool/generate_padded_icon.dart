import 'dart:io';
import 'package:image/image.dart' as img;

// Simple script to center the existing horizontal logo into a square canvas
// with padding so it doesn't appear vertically stretched as launcher icon.
// Usage:
// dart run tool/generate_padded_icon.dart
// Then run: flutter pub run flutter_launcher_icons
void main() {
  const sourcePath = 'assets/images/logo.png';
  const targetPath = 'assets/images/logo_padded.png';

  final file = File(sourcePath);
  if (!file.existsSync()) {
    stderr.writeln('Source logo not found at $sourcePath');
    exit(1);
  }
  final bytes = file.readAsBytesSync();
  final original = img.decodeImage(bytes);
  if (original == null) {
    stderr.writeln('Failed to decode image.');
    exit(2);
  }

  // Determine square size: max(width, height) plus some breathing space.
  final maxSide = original.width > original.height
      ? original.width
      : original.height;
  final canvasSide = (maxSide * 1.18).round(); // 35% extra space (refined)

  // Create transparent canvas (iOS) - RGBA 0,0,0,0
  final canvas = img.Image(width: canvasSide, height: canvasSide);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  // Center position
  final dx = (canvasSide - original.width) ~/ 2;
  final dy = (canvasSide - original.height) ~/ 2;

  // Composite
  img.compositeImage(canvas, original, dstX: dx, dstY: dy);

  // Optionally apply a subtle scale if image nearly fills canvas
  // (Skipped for simplicity)

  // Export as PNG
  final outBytes = img.encodePng(canvas);
  File(targetPath).writeAsBytesSync(outBytes);
  stdout.writeln('Generated padded icon -> $targetPath (side=$canvasSide)');
}
