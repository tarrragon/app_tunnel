import 'package:flutter/material.dart';

import 'package:app_tunnel/core/constants/ui_constants.dart';
import 'package:app_tunnel/core/theme/app_colors.dart';
import 'package:app_tunnel/core/theme/app_spacing.dart';
import 'package:app_tunnel/core/theme/app_typography.dart';
import 'package:app_tunnel/l10n/app_localizations.dart';
import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/enrollment/qr_scanner_screen.dart';
import 'package:app_tunnel/shared/widgets/primary_action_button.dart';

/// Requirement: [UC-01] Full enrollment flow — scan QR, parse, save credential.
/// Flow: tap scan → QrScannerScreen → parse credential → check existing → save → done.
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
    final credential = await Navigator.of(context).push<Credential>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (credential == null || !mounted) return;

    await _processCredential(credential);
  }

  /// Requirement: [UC-01] Check existing credential, save scanned credential.
  Future<void> _processCredential(Credential credential) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
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
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.enrollmentOverwriteTitle),
        content: Text(l10n.enrollmentOverwriteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.enrollmentReplaceButton),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).enrollmentSaveSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).enrollmentTitle)),
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.kSpaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIconPanel(),
          const SizedBox(height: AppSpacing.kSpaceLg),
          _buildInstruction(l10n.enrollmentInstruction),
          const SizedBox(height: AppSpacing.kSpaceXl),
          SizedBox(
            width: double.infinity,
            child: PrimaryActionButton(
              onPressed: _startEnrollment,
              icon: Icons.camera_alt,
              label: l10n.enrollmentScanButton,
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: AppSpacing.kSpaceLg),
            _buildStatusChip(_statusMessage!),
          ],
        ],
      ),
    );
  }

  /// QR icon 框於 surface 圓盤中，作配對動作的儀表焦點。
  Widget _buildIconPanel() {
    return Container(
      width: UiConstants.enrollmentIconSize + AppSpacing.kSpaceXl,
      height: UiConstants.enrollmentIconSize + AppSpacing.kSpaceXl,
      decoration: const BoxDecoration(
        color: AppColors.kColorSurface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.qr_code_scanner,
        size: UiConstants.enrollmentIconSize,
        color: AppColors.kColorPrimary,
      ),
    );
  }

  /// 配對說明：次要墨色置中，承載 body 階層。
  Widget _buildInstruction(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.kColorInkMuted,
        fontSize: AppTypography.kFontBodySize,
        fontWeight: AppTypography.kFontBodyWeight,
        height: AppTypography.kLineHeightUi,
      ),
    );
  }

  /// 狀態訊息：以語意色填底的 surface chip，提升信號可見度。
  Widget _buildStatusChip(String message) {
    final isSuccess = message.contains('successful');
    final statusColor = isSuccess
        ? AppColors.kColorStatusConnected
        : AppColors.kColorStatusError;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.kSpaceMd,
        vertical: AppSpacing.kSpaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.kColorSurface,
        borderRadius: BorderRadius.circular(AppSpacing.kSpaceSm),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            size: AppTypography.kFontBodySize,
            color: statusColor,
          ),
          const SizedBox(width: AppSpacing.kSpaceXs),
          Text(
            message,
            style: TextStyle(
              color: statusColor,
              fontSize: AppTypography.kFontLabelSize,
              fontWeight: AppTypography.kFontLabelWeight,
            ),
          ),
        ],
      ),
    );
  }
}
