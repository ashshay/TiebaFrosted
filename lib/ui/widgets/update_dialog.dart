import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../data/updater.dart';

/// 发现有新版本时的提示弹窗。返回 true 表示用户要立即去更新。
Future<bool?> showUpdateDialog(
  BuildContext context,
  UpdateInfo info, {
  String currentVersion = '',
}) {
  final scheme = context.colorScheme;
  final notes = plainReleaseNotes(info.notes);
  return showFloatingDialog<bool>(
    context: context,
    child: AlertDialog(
      title: '发现新版本 v${info.version}',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('稍后'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('去更新'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentVersion.isNotEmpty)
            Text(
              '当前版本 v$currentVersion',
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Text(
                  notes,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: scheme.onSurface),
                ),
              ),
            ),
          ],
          if (info.sizeLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '安装包 ${info.sizeLabel}',
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    ),
  );
}
