import 'package:flutter/material.dart';

import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/enrollment/credential_payload.dart';
import 'package:app_tunnel/features/enrollment/qr_scanner_screen.dart';

/// Requirement: [UC-01] Full enrollment flow — scan QR, parse, save credential.
/// Flow: tap scan → QrScannerScreen → parse payload → check existing → save → done.
/// Constraint: if credential already exists, show overwrite confirmation (UC-03).
class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({
    required this.credentialRepository,
    super.key,
  });

  final CredentialRepository credentialRepository;

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  bool _isProcessing = false;
  String? _statusMessage;

  /// Requirement: [UC-01] Launch QR scanner and handle result.
  Future<void> _startEnrollment() async {
    final payload = await Navigator.of(context).push<CredentialPayload>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (payload == null || !mounted) return;

    await _processPayload(payload);
  }

  /// Requirement: [UC-01] Convert payload to credential, check existing, save.
  Future<void> _processPayload(CredentialPayload payload) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final credential = _toCredential(payload);
      final hasExisting = await widget.credentialRepository.exists();

      if (hasExisting && mounted) {
        final confirmed = await _showOverwriteDialog();
        if (confirmed != true) {
          setState(() => _isProcessing = false);
          return;
        }
      }

      await widget.credentialRepository.save(credential);

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Enrollment successful';
      });
      _showSuccessSnackBar();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Enrollment failed: $e';
      });
    }
  }

  /// Requirement: [UC-03] Overwrite confirmation when credential exists.
  Future<bool?> _showOverwriteDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Overwrite Credential'),
        content: const Text(
          'A credential already exists. Do you want to replace it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Credential saved successfully')),
    );
  }

  /// Convert parsed QR payload to storable credential.
  Credential _toCredential(CredentialPayload payload) {
    return Credential(
      version: payload.version,
      protocol: payload.protocol,
      endpoint: payload.endpoint,
      ttydUser: payload.ttydUser,
      ttydPass: payload.ttydPass,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Enrollment')),
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.qr_code_scanner, size: 96),
        const SizedBox(height: 24),
        const Text('Scan the QR code from your server to pair this device.'),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _startEnrollment,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Scan QR Code'),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _statusMessage!,
            style: TextStyle(
              color: _statusMessage!.contains('successful')
                  ? Colors.green
                  : Colors.red,
            ),
          ),
        ],
      ],
    );
  }
}
