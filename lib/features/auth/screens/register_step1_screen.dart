// lib/features/auth/screens/register_step1_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';

class RegisterStep1Screen extends StatefulWidget {
  const RegisterStep1Screen({super.key});
  @override
  State<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends State<RegisterStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true, _obscure2 = true;

  @override
  void dispose() { _passCtrl.dispose(); _confirmCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
        title: const Text('Регистрация'),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepIndicator(step: 1),
                const SizedBox(height: 28),
                Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.key_rounded, color: AppColors.accent, size: 26)),
                const SizedBox(height: 16),
                Text('Придумайте пароль', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
                const SizedBox(height: 6),
                const Text('Минимум 6 символов', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextFormField(controller: _passCtrl, obscureText: _obscure1,
                        decoration: InputDecoration(labelText: 'Пароль',
                          suffixIcon: IconButton(icon: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
                            onPressed: () => setState(() => _obscure1 = !_obscure1))),
                        validator: (v) => (v == null || v.length < 6) ? 'Минимум 6 символов' : null),
                      const SizedBox(height: 14),
                      TextFormField(controller: _confirmCtrl, obscureText: _obscure2,
                        decoration: InputDecoration(labelText: 'Повторите пароль',
                          suffixIcon: IconButton(icon: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
                            onPressed: () => setState(() => _obscure2 = !_obscure2))),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Подтвердите пароль';
                          if (v != _passCtrl.text) return 'Пароли не совпадают';
                          return null;
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () { if (_formKey.currentState!.validate()) context.go(AppRoutes.register2, extra: _passCtrl.text); },
                  child: const Text('Далее'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// lib/features/auth/screens/register_step2_screen.dart
// ─────────────────────────────────────────────────────────────

class RegisterStep2Screen extends ConsumerStatefulWidget {
  final String password;
  const RegisterStep2Screen({super.key, required this.password});

  @override
  ConsumerState<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends ConsumerState<RegisterStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _loginCtrl.dispose(); _lastNameCtrl.dispose(); _firstNameCtrl.dispose(); _orgCtrl.dispose(); _emailCtrl.dispose(); super.dispose(); }

  bool _validEmail(String e) => RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(e);
  bool _validLogin(String v) => RegExp(r'^[a-zA-Z0-9_]{3,}$').hasMatch(v);

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final err = await ref.read(authProvider.notifier).register(
      login: _loginCtrl.text.trim(),
      password: widget.password,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      organization: _orgCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
    // On success GoRouter redirect fires automatically.
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
        title: const Text('Регистрация'),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepIndicator(step: 2),
                const SizedBox(height: 28),
                Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.person_outline_rounded, color: AppColors.accent, size: 26)),
                const SizedBox(height: 16),
                Text('Личные данные', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    TextFormField(
                      controller: _loginCtrl,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        labelText: 'Логин',
                        hintText: 'ivan_petrov',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Введите логин';
                        if (!_validLogin(v.trim())) return 'Только буквы, цифры и _, минимум 3 символа';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _field(_lastNameCtrl, 'Фамилия', req: true),
                    const SizedBox(height: 12),
                    _field(_firstNameCtrl, 'Имя', req: true),
                    const SizedBox(height: 12),
                    _field(_orgCtrl, 'Организация', req: true),
                    const SizedBox(height: 12),
                    TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-mail', hintText: 'example@mail.com'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Введите email';
                        if (!_validEmail(v.trim())) return 'Некорректный email';
                        return null;
                      }),
                  ]),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _loading ? null : _finish,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDark))
                      : const Text('Завершить регистрацию'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool req = false}) =>
    TextFormField(controller: c, textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: label),
      validator: req ? (v) => (v == null || v.trim().isEmpty) ? 'Заполните поле' : null : null);
}

// ─── Step indicator ───────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(2, (i) {
        final s = i + 1;
        final active = s == step;
        final done = s < step;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 1 ? 8 : 0),
            child: Column(children: [
              Container(height: 4,
                decoration: BoxDecoration(
                  color: active || done ? AppColors.accent : AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                )),
              const SizedBox(height: 5),
              Text('Шаг $s', style: TextStyle(
                fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.accent : AppColors.textMuted)),
            ]),
          ),
        );
      }),
    );
  }
}
