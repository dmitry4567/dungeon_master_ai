import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/fantasy_button.dart';
import '../../../../shared/widgets/themed_icon_button.dart';

/// Форма входа/регистрации по email — фэнтези тёмный стиль
class EmailLoginForm extends StatefulWidget {
  const EmailLoginForm({
    required this.onLogin,
    required this.onRegister,
    super.key,
    this.isLoading = false,
  });

  final void Function(String email, String password) onLogin;
  final void Function(String email, String password, String name) onRegister;
  final bool isLoading;

  @override
  State<EmailLoginForm> createState() => _EmailLoginFormState();
}

class _EmailLoginFormState extends State<EmailLoginForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  late final AnimationController _modeController;

  @override
  void initState() {
    super.initState();
    _modeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _modeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isRegisterMode) {
      widget.onRegister(email, password, _nameController.text.trim());
    } else {
      widget.onLogin(email, password);
    }
  }

  void _toggleMode() {
    setState(() => _isRegisterMode = !_isRegisterMode);
    if (_isRegisterMode) {
      _modeController.forward();
    } else {
      _modeController.reverse();
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Введите email';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Некорректный email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Введите пароль';
    if (value.length < 6) return 'Минимум 6 символов';
    return null;
  }

  String? _validateName(String? value) {
    if (!_isRegisterMode) return null;
    if (value == null || value.isEmpty) return 'Введите имя';
    if (value.length < 2) return 'Минимум 2 символа';
    return null;
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок секции
            _buildSectionTitle(),

            const SizedBox(height: 20),

            // Поле имени (только при регистрации)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isRegisterMode
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildField(
                        controller: _nameController,
                        label: 'Имя персонажа',
                        hint: 'Как тебя звать, искатель приключений?',
                        icon: Icons.person_outline,
                        validator: _validateName,
                        inputAction: TextInputAction.next,
                        capitalization: TextCapitalization.words,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Email
            _buildField(
              controller: _emailController,
              label: 'Email',
              hint: 'your@email.com',
              icon: Icons.alternate_email,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              inputAction: TextInputAction.next,
              autocorrect: false,
            ),

            const SizedBox(height: 12),

            // Пароль
            _buildPasswordField(),

            const SizedBox(height: 24),

            // Кнопка действия
            FantasyButton(
              label: _isRegisterMode ? 'Создать аккаунт' : 'Войти',
              icon: _isRegisterMode ? Icons.auto_stories : Icons.login,
              onPressed: widget.isLoading ? null : _submit,
              isLoading: widget.isLoading,
            ),

            const SizedBox(height: 16),

            // Переключение режима
            _buildModeToggle(),
          ],
        ),
      );

  Widget _buildSectionTitle() => Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isRegisterMode ? 'Создать аккаунт' : 'Войти по Email',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? inputAction,
    TextCapitalization capitalization = TextCapitalization.none,
    bool autocorrect = true,
  }) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: Colors.white38),
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFF0D0D1A),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A2A4E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFD4AF37),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.7)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: const TextStyle(color: Colors.white, fontSize: 15),
        keyboardType: keyboardType,
        textInputAction: inputAction,
        textCapitalization: capitalization,
        autocorrect: autocorrect,
        validator: validator,
        enabled: !widget.isLoading,
      );

  Widget _buildPasswordField() => TextFormField(
        controller: _passwordController,
        decoration: InputDecoration(
          labelText: 'Пароль',
          hintText: '••••••••',
          prefixIcon:
              const Icon(Icons.lock_outline, size: 20, color: Colors.white38),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(8),
            child: ThemedIconButton(
              icon: _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              onPressed: widget.isLoading
                  ? null
                  : () => setState(() => _obscurePassword = !_obscurePassword),
              iconColor: Colors.white38,
              backgroundColor: Colors.transparent,
              padding: 4,
              iconSize: 20,
            ),
          ),
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFF0D0D1A),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A2A4E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFD4AF37),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.7)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: const TextStyle(color: Colors.white, fontSize: 15),
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        validator: _validatePassword,
        enabled: !widget.isLoading,
        onFieldSubmitted: (_) => _submit(),
      );

  Widget _buildModeToggle() => GestureDetector(
        onTap: widget.isLoading ? null : _toggleMode,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isRegisterMode
                    ? 'Уже есть аккаунт? '
                    : 'Нет аккаунта? ',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),
              Text(
                _isRegisterMode ? 'Войти' : 'Зарегистрироваться',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}
