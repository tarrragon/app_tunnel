import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:app_tunnel/l10n/app_localizations.dart';
import 'package:app_tunnel/core/constants/ui_constants.dart';
import 'package:app_tunnel/core/theme/app_colors.dart';
import 'package:app_tunnel/core/theme/app_spacing.dart';
import 'package:app_tunnel/core/errors/enrollment_errors.dart';
import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/enrollment/credential_payload_parser.dart';

/// Full-screen QR scanner for one-time credential enrollment.
///
/// Requirement: [UC-01] Scan QR once to capture credential.
/// On successful scan, pops with [Credential] as result.
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
      final credential = _parser.parse(barcode!.rawValue!);
      _processed = true;
      Navigator.of(context).pop(credential);
    } on EnrollmentError catch (e) {
      setState(() => _errorMessage = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).enrollmentScanTitle)),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),
          _buildScanCutout(),
          _buildScanFrame(),
          if (_errorMessage != null) _buildErrorBanner(),
        ],
      ),
    );
  }

  /// 暗化全屏並挖空中央對焦區（srcOut 鏤空）。
  Widget _buildScanCutout() {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        AppColors.kColorScrim,
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            // 非 UI 語意色：dstOut 遮罩僅取其不透明度挖空中央掃描區，
            // RGB 值不影響呈現，故維持框架 Colors.black 不納入主題 token。
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: UiConstants.qrScanFrameSize,
              height: UiConstants.qrScanFrameSize,
              decoration: BoxDecoration(
                // 任意不透明色；srcOut 將其轉為鏤空。
                color: Colors.black,
                borderRadius: BorderRadius.circular(AppSpacing.kSpaceMd),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 對焦框：cobalt 描邊標示掃描區，作儀表式取景框。
  Widget _buildScanFrame() {
    return Center(
      child: Container(
        width: UiConstants.qrScanFrameSize,
        height: UiConstants.qrScanFrameSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.kSpaceMd),
          border: Border.all(
            color: AppColors.kColorPrimary,
            width: AppSpacing.kSpaceXs / 2,
          ),
        ),
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
            child: Text(AppLocalizations.of(context).commonDismiss),
          ),
        ],
      ),
    );
  }
}
