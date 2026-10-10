import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../lang.dart';
import '../../theme.dart';

/// Camera QR scanner: live ML Kit scan + torch + gallery fallback.
/// Returns the decoded string via Navigator.pop (null when dismissed).
/// Everything runs on-device; only the decoded *text* leaves this screen.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  late final MobileScannerController _controller;
  final _picker = ImagePicker();
  bool _done = false;
  bool _busyGallery = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      torchEnabled: false,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String? raw) {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(raw?.trim().isEmpty == true ? null : raw?.trim());
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim() ?? '';
      if (v.isNotEmpty) {
        _finish(v);
        return;
      }
    }
  }

  Future<void> _pickGallery() async {
    if (_busyGallery) return;
    setState(() => _busyGallery = true);
    try {
      final file =
          await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final capture = await _controller.analyzeImage(file.path);
      final found = capture?.barcodes
          .map((b) => b.rawValue?.trim() ?? '')
          .firstWhere((v) => v.isNotEmpty, orElse: () => '');
      if (!mounted) return;
      if (found != null && found.isNotEmpty) {
        _finish(found);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('scanEmpty'))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('scanEmpty'))),
      );
    } finally {
      if (mounted) setState(() => _busyGallery = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(context.tr('scanQr')),
        actions: [
          IconButton(
            tooltip: 'torch',
            onPressed: () {
              try {
                _controller.toggleTorch();
              } catch (_) {}
            },
            icon: const Icon(Icons.flashlight_on_rounded),
          ),
          IconButton(
            tooltip: 'gallery',
            onPressed: _busyGallery ? null : _pickGallery,
            icon: const Icon(Icons.photo_library_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.tr('scanDenied'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.6),
                ),
              ),
            ),
          ),
          // Scan-frame overlay (pure decoration, never blocks detection).
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: CyberSafeColors.teal, width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: Text(
              context.tr('scanHint'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
