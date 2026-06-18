// 需求：[1.2.0-W1-024] home 畫面深色「儀表艙」視覺重設計
// 來源：ANA 1.2.0-W1-014 方案 C（深 cobalt 夜空 + amber accent 信號燈）。
// 約束：僅調版面層級/間距節奏/留白/元件用法，沿用既有 token
//       （AppColors/AppSpacing/AppTypography）；不新增硬編碼值。
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:app_tunnel/core/theme/app_colors.dart';
import 'package:app_tunnel/core/theme/app_spacing.dart';
import 'package:app_tunnel/core/theme/app_typography.dart';
import 'package:app_tunnel/l10n/app_localizations.dart';
import 'package:app_tunnel/shared/widgets/primary_action_button.dart';

/// 首頁「儀表艙」入口畫面。
///
/// 視覺層級：品牌標誌（display）→ headline 標語（muted body）→ 主操作。
/// 大留白置中，給單手低光操作的安靜聚焦感。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeAppBarTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.kSpaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBrandMark(),
              const SizedBox(height: AppSpacing.kSpaceLg),
              _buildHeadline(l10n.homeHeadline),
              const SizedBox(height: AppSpacing.kSpaceXl),
              _buildConnectButton(context, l10n.homeConnectButton),
              const SizedBox(height: AppSpacing.kSpaceMd),
              _buildEnrollButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 品牌標誌：cobalt 圓盤襯托終端 glyph，作儀表盤焦點。
  Widget _buildBrandMark() {
    return Container(
      width: AppSpacing.kSpaceXl * 2,
      height: AppSpacing.kSpaceXl * 2,
      decoration: const BoxDecoration(
        color: AppColors.kColorSurface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.terminal,
        size: AppSpacing.kSpaceXl,
        color: AppColors.kColorPrimary,
      ),
    );
  }

  /// 標語：次要墨色置中，承載 body 階層。
  Widget _buildHeadline(String text) {
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

  /// 配對入口：次要樣式，導航至 enrollment 掃描 QR。
  Widget _buildEnrollButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('enroll_button'),
        onPressed: () => context.push('/enrollment'),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Enroll Device'), // i18n-exempt
      ),
    );
  }

  /// 主操作：全寬 cobalt 按鈕，畫面唯一強調動作。
  Widget _buildConnectButton(BuildContext context, String label) {
    return SizedBox(
      width: double.infinity,
      child: PrimaryActionButton(
        key: const Key('connect_terminal_button'),
        onPressed: () => context.go('/terminal'),
        icon: Icons.terminal,
        label: label,
      ),
    );
  }
}
