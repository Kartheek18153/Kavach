import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../lang.dart';
import '../../services/scan_history.dart';
import '../../services/scanners.dart';
import '../../widgets/cards.dart';
import '../../widgets/scan_widgets.dart';
import 'qr_scan_screen.dart';

/// Combined QR + UPI checker: one field, auto-detects payment vs QR
/// content, runs the matching engine, and says which one it checked.
class QrUpiScreen extends StatefulWidget {
  const QrUpiScreen({super.key});

  @override
  State<QrUpiScreen> createState() => _QrUpiScreenState();
}

class _QrUpiScreenState extends State<QrUpiScreen> {
  final _ctrl = TextEditingController();
  ScanFinding? _finding;
  String _kind = 'qr';
  bool _receiving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Camera scan: requests permission, opens the scanner, fills the
  /// field with the decoded text and analyzes immediately.
  Future<void> _scan() async {
    bool granted = false;
    try {
      granted = await Permission.camera.request().isGranted;
    } catch (_) {}
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('scanDenied'))),
      );
      return;
    }
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;
    setState(() => _ctrl.text = raw.trim());
    _analyze();
  }

  /// Gallery fallback: decodes a QR from a picked image without the camera.
  Future<void> _pickGalleryDirect() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery)
        .catchError((_) => null);
    if (file == null || !mounted) return;
    String found = '';
    final controller = MobileScannerController();
    try {
      final capture = await controller.analyzeImage(file.path);
      found = capture?.barcodes
              .map((b) => b.rawValue?.trim() ?? '')
              .firstWhere((v) => v.isNotEmpty, orElse: () => '') ??
          '';
    } catch (_) {
    } finally {
      controller.dispose();
    }
    if (!mounted) return;
    if (found.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('scanEmpty'))),
      );
      return;
    }
    setState(() => _ctrl.text = found);
    _analyze();
  }

  void _analyze() {
    final r = scoreQrUpi(_ctrl.text, expectsIncoming: _receiving);
    final level = levelNameFor(r.finding.risk);
    setState(() {
      _finding = r.finding;
      _kind = r.kind;
    });
    ScanHistoryStore.add(ScanRecord(
      kind: r.kind,
      input: previewOf(_ctrl.text),
      risk: r.finding.risk,
      level: level,
      reasons: r.finding.reasons,
      ts: DateTime.now().toIso8601String(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('toolQrUpi'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('scanSub'),
                    style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13.5,
                        height: 1.5)),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  maxLines: 3,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: context.tr('qrUpiHint'),
                    prefixIcon: const Icon(Icons.qr_code_2_rounded),
                    suffixIcon: _ctrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() {
                              _ctrl.clear();
                              _finding = null;
                            }),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(context.tr('expectPay'),
                              textAlign: TextAlign.center),
                        ),
                        selected: !_receiving,
                        onSelected: (_) =>
                            setState(() => _receiving = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(context.tr('expectReceive'),
                              textAlign: TextAlign.center),
                        ),
                        selected: _receiving,
                        onSelected: (_) =>
                            setState(() => _receiving = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _scan,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(context.tr('scanQr')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickGalleryDirect,
                        icon: const Icon(Icons.photo_library_rounded),
                        label: Text(context.tr('scanGallery')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _ctrl.text.trim().isEmpty ? null : _analyze,
                    icon: const Icon(Icons.shield_rounded),
                    label: Text(context.tr('analyzeBtn')),
                  ),
                ),
              ],
            ),
          ),
          if (_finding != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                context.trP('autoKind',
                    {'kind': _kind == 'upi' ? 'UPI' : 'QR'}),
                style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            ScanResultCard(finding: _finding!),
          ],
          const SizedBox(height: 14),
          ToolTipCard(context.tr(_kind == 'upi' ? 'tipUpi' : 'tipQr')),
        ],
      ),
    );
  }
}
