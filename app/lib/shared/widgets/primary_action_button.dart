// 需求：[1.2.0-W1-022] 統一主操作按鈕為單一 component
// 來源：ANA 1.2.0-W1-014 Solution（IMP-2）— 消除 home FilledButton /
//       enrollment ElevatedButton / terminal ElevatedButton 三種「主操作」形狀。
// 約束：唯一主操作按鈕 widget；樣式由全域深色 theme 的 FilledButton 主題承載，
//       本 component 不行內硬編碼顏色（顏色散點屬 020/021，此處不碰）。
import 'package:flutter/material.dart';

/// 全 app 唯一的主操作按鈕。
///
/// 取代散落的 FilledButton/ElevatedButton 主操作用法，統一 component vocabulary。
/// 視覺（顏色/字級/形狀）由 ThemeData.filledButtonTheme 集中承載。
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  /// 按鈕文字（verb + object，由呼叫端提供已多語系化字串）。
  final String label;

  /// 點擊回呼；為 null 時按鈕停用。
  final VoidCallback? onPressed;

  /// 可選前置 icon。
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return FilledButton(
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
