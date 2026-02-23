import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/fantasy_button.dart';

/// Форма входа по email
class EmailLoginForm extends StatefulWidget {
  const EmailLoginForm({
    required this.onLogin, required this.onRegister, super.key,
    this.isLoading = false,
  });

  final void Function(String email, String password) onLogin;
  final void Function(String email, String password, String name) onRegister;
  final bool isLoading;

  @override
  State<EmailLoginForm> createState() => _EmailLoginFormState();
}

class _EmailLoginFormState extends State<EmailLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Некорректный email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < 6) {
      return 'Пароль должен быть не менее 6 символов';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (!_isRegisterMode) return null;
    if (value == null || value.isEmpty) {
      return 'Введите имя';
    }
    if (value.length < 2) {
      return 'Имя должно быть не менее 2 символов';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name field (only in register mode)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _isRegisterMode
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Имя',
                          hintText: 'Ваше имя в игре',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: _validateName,
                        enabled: !widget.isLoading,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Email field
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'your@email.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: _validateEmail,
              enabled: !widget.isLoading,
            ),

            const SizedBox(height: 16),

            // Password field
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Пароль',
                hintText: '••••••',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              validator: _validatePassword,
              enabled: !widget.isLoading,
              onFieldSubmitted: (_) => _submit(),
            ),

            const SizedBox(height: 24),

            // Submit button
            FantasyButton(
              label: _isRegisterMode ? 'Зарегистрироваться' : 'Войти',
              onPressed: widget.isLoading ? null : _submit,
              isLoading: widget.isLoading,
            ),

            const SizedBox(height: 16),

            // Toggle register/login
            TextButton(
              onPressed: widget.isLoading
                  ? null
                  : () => setState(() => _isRegisterMode = !_isRegisterMode),
              child: Text(
                _isRegisterMode
                    ? 'Уже есть аккаунт? Войти'
                    : 'Нет аккаунта? Зарегистрироваться',
                style: const TextStyle(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
}
