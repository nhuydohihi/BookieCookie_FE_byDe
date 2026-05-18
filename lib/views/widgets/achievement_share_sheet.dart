import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/achievement_share_service.dart';
import '../../data/models/achievement_model.dart';
import 'achievement_share_card.dart';

Future<void> showAchievementShareSheet(
  BuildContext context, {
  required AchievementModel achievement,
}) {
  precacheImage(const AssetImage('assets/images/badge.png'), context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AchievementShareSheet(achievement: achievement),
  );
}

class _AchievementShareSheet extends StatefulWidget {
  const _AchievementShareSheet({required this.achievement});

  final AchievementModel achievement;

  @override
  State<_AchievementShareSheet> createState() => _AchievementShareSheetState();
}

class _AchievementShareSheetState extends State<_AchievementShareSheet> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isProcessing = false;

  Future<void> _handleSave() async {
    await _runAction(
      successMessage: 'Achievement image saved to your gallery.',
      action: (bytes, fileName, _) async {
        await AchievementShareService.saveToGallery(
          bytes: bytes,
          fileName: fileName,
        );
      },
    );
  }

  Future<void> _handleShare() async {
    await _runAction(
      successMessage: 'Share sheet opened.',
      action: (bytes, fileName, format) async {
        final file = await AchievementShareService.writeTempImage(
          bytes: bytes,
          fileName: fileName,
          format: format,
        );

        await AchievementShareService.shareImage(
          file: file,
          text:
              'I just unlocked ${widget.achievement.name} on BookieCookie. #BookieCookie',
        );
      },
    );
  }

  Future<void> _runAction({
    required String successMessage,
    required Future<void> Function(
      Uint8List bytes,
      String fileName,
      ImageExportFormat format,
    )
    action,
  }) async {
    if (_isProcessing) {
      return;
    }

    final boundary =
        _captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    if (boundary == null) {
      _showSnackBar('Preview is not ready yet. Please try again.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final bytes = await AchievementShareService.captureWidget(
        boundary,
        format: ImageExportFormat.png,
        pixelRatio: 3,
      );
      final fileName = _buildFileName(widget.achievement);

      await action(bytes, fileName, ImageExportFormat.png);
      _showSnackBar(successMessage);
    } catch (_) {
      _showSnackBar(
        'Could not export the achievement image. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 6, 16, bottomInset + 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Save or share achievement',
                              style: TextStyle(
                                color: AppColors.darkBlue,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RepaintBoundary(
                    key: _captureKey,
                    child: AchievementShareCard(
                      achievement: widget.achievement,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _handleSave,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_rounded),
                          label: const Text('Save'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.darkBlue,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isProcessing ? null : _handleShare,
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text('Share'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _buildFileName(AchievementModel achievement) {
  final name = achievement.name.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '-',
  );
  return 'bookiecookie-achievement-$name';
}
