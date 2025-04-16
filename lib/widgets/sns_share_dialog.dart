// lib/widgets/sns_share_dialog.dart
import 'package:flutter/material.dart';
import '../repositories/coin_repository.dart';

class SnsShareDialog extends StatelessWidget {
  final Function() onClose;
  final Function(String platform) onShare;

  const SnsShareDialog({Key? key, required this.onClose, required this.onShare})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with coin reward info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.share, color: Colors.amber, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'SNSシェアで100ポイントGET!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'お気に入りの絵本を友達にシェアしよう',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),

            // Social media options
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'シェア先を選択',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(
                        context: context,
                        icon: 'assets/icons/twitter.png',
                        label: 'Twitter',
                        color: const Color(0xFF1DA1F2),
                        onTap: () => onShare('twitter'),
                      ),
                      _buildSocialButton(
                        context: context,
                        icon: 'assets/icons/instagram.png',
                        label: 'Instagram',
                        color: const Color(0xFFE1306C),
                        onTap: () => onShare('instagram'),
                      ),
                      _buildSocialButton(
                        context: context,
                        icon: 'assets/icons/facebook.png',
                        label: 'Facebook',
                        color: const Color(0xFF1877F2),
                        onTap: () => onShare('facebook'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(
                        context: context,
                        icon: 'assets/icons/line.png',
                        label: 'LINE',
                        color: const Color(0xFF06C755),
                        onTap: () => onShare('line'),
                      ),
                      _buildSocialButton(
                        context: context,
                        icon: 'assets/icons/mail.png',
                        label: 'メール',
                        color: const Color(0xFF9E9E9E),
                        onTap: () => onShare('mail'),
                      ),
                      _buildSocialButton(
                        context: context,
                        icon: 'assets/icons/others.png',
                        label: 'その他',
                        color: const Color(0xFF607D8B),
                        onTap: () => onShare('others'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Cancel button
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: const Text(
                    'キャンセル',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required String icon,
    required String label,
    required Color color,
    required Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1),
            ),
            child: Center(child: _loadSocialIcon(icon, color)),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  // アイコン表示のエラーハンドリングを改善
  Widget _loadSocialIcon(String iconPath, Color fallbackColor) {
    return Builder(
      builder: (context) {
        try {
          return ClipOval(
            child: Image.asset(
              iconPath,
              width: 30,
              height: 30,
              errorBuilder: (context, error, stackTrace) {
                // アイコンフォールバック
                return Icon(Icons.share, color: fallbackColor, size: 28);
              },
            ),
          );
        } catch (e) {
          // 例外ハンドリング
          return Icon(Icons.share, color: fallbackColor, size: 28);
        }
      },
    );
  }
}
