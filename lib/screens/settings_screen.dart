// ---- settings_screen.dart ----

import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),

          // アプリ設定セクション
          _buildSectionHeader('アプリ設定'),
          _buildSettingItem('言語', '日本語', Icons.language, () {}),
          _buildSettingItem('テーマ', 'ライト', Icons.color_lens, () {}),
          _buildSettingItem('フォントサイズ', '中', Icons.format_size, () {}),

          const SizedBox(height: 20),

          // 通知設定セクション
          _buildSectionHeader('通知設定'),
          _buildSwitchItem('プッシュ通知', true, (value) {}),
          _buildSwitchItem('お知らせメール', false, (value) {}),

          const SizedBox(height: 20),

          // アカウント設定セクション
          _buildSectionHeader('アカウント'),
          _buildSettingItem('アカウント情報', '', Icons.person, () {}),
          _buildSettingItem('パスワード変更', '', Icons.lock, () {}),
          _buildSettingItem('ログアウト', '', Icons.exit_to_app, () {}),

          const SizedBox(height: 20),

          // その他セクション
          _buildSectionHeader('その他'),
          _buildSettingItem('アプリについて', '', Icons.info, () {}),
          _buildSettingItem('プライバシーポリシー', '', Icons.privacy_tip, () {}),
          _buildSettingItem('利用規約', '', Icons.description, () {}),

          const SizedBox(height: 30),

          // アプリバージョン
          Center(
            child: Text(
              'アプリバージョン: 1.0.0',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // セクションヘッダーウィジェット
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // 設定項目ウィジェット
  Widget _buildSettingItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  // スイッチ付き設定項目ウィジェット
  Widget _buildSwitchItem(
    String title,
    bool initialValue,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      value: initialValue,
      onChanged: onChanged,
      activeColor: Colors.green,
    );
  }
}
