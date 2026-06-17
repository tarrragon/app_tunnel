import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:app_tunnel/core/errors/enrollment_errors.dart';
import 'package:app_tunnel/features/enrollment/credential_payload.dart';
import 'package:app_tunnel/features/enrollment/credential_payload_parser.dart';

/// Full-screen QR scanner for one-time credential enrollment.
///
/// Requirement: [UC-01] Scan QR once to capture credential payload.
/// On successful scan, pops with [CredentialPayload] as result.
/// On parse error, shows inline error message and continues scanning.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _parser = const CredentialPayloadParser();
  final _controller = MobileScannerController();
  String? _errorMessage;
  bool _processed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_processed) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    try {
      final payload = _parser.parse(barcode!.rawValue!);
      _processed = true;
      Navigator.of(context).pop(payload);
    } on EnrollmentError catch (e) {
      setState(() => _errorMessage = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),
          _buildScanOverlay(),
          if (_errorMessage != null) _buildErrorBanner(),
        ],
      ),
    );
  }

  /// Semi-transparent overlay with a clear center scanning area.
  Widget _buildScanOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withAlpha(128),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.red, // Any color; srcOut makes it transparent.
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom error banner shown on parse failure.
  Widget _buildErrorBanner() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: MaterialBanner(
        content: Text(_errorMessage!),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        actions: [
          TextButton(
            onPressed: () => setState(() => _errorMessage = null),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}
