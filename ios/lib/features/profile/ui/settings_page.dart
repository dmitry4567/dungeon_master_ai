import 'package:flutter/material.dart';

/// Страница настроек
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Профиль'),
                  subtitle: const Text('Управление профилем и аккаунтом'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Уведомления'),
                  subtitle: const Text('Настройка push-уведомлений'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to notifications settings
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.volume_up),
                  title: const Text('Звук'),
                  subtitle: const Text('TTS и голосовой ввод'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to sound settings
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Конфиденциальность'),
                  subtitle: const Text('Политика конфиденциальности'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show privacy policy
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Условия использования'),
                  subtitle: const Text('Правила сервиса'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show terms of service
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('О приложении'),
                  subtitle: const Text('Версия 1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'AI Dungeon Master',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2026 AI Dungeon Master',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
}
