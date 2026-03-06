import 'package:flutter/material.dart';

/// Страница настроек
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Настройки',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white70),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection(
              context,
              title: 'Аккаунт',
              items: [
                _SettingsItem(
                  icon: Icons.person_outline,
                  label: 'Профиль',
                  subtitle: 'Управление профилем и аккаунтом',
                  onTap: () => Navigator.pop(context),
                ),
                _SettingsItem(
                  icon: Icons.notifications_outlined,
                  label: 'Уведомления',
                  subtitle: 'Настройка push-уведомлений',
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.volume_up_outlined,
                  label: 'Звук',
                  subtitle: 'TTS и голосовой ввод',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: 'Информация',
              items: [
                _SettingsItem(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Конфиденциальность',
                  subtitle: 'Политика конфиденциальности',
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.description_outlined,
                  label: 'Условия использования',
                  subtitle: 'Правила сервиса',
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.info_outlined,
                  label: 'О приложении',
                  subtitle: 'Версия 1.0.0',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'AI Dungeon Master',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2026 AI Dungeon Master',
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<_SettingsItem> items,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A4E)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _buildTile(items[i]),
                  if (i < items.length - 1)
                    const Divider(
                      height: 1,
                      color: Color(0xFF2A2A4E),
                      indent: 56,
                    ),
                ],
              ],
            ),
          ),
        ],
      );

  Widget _buildTile(_SettingsItem item) => InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A4A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  size: 18,
                  color: const Color(0xFFD4AF37),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.subtitle != null)
                      Text(
                        item.subtitle!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF3A3A5E),
                size: 20,
              ),
            ],
          ),
        ),
      );
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
}
