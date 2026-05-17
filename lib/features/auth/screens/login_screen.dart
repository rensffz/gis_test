// lib/features/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../models/app_models.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true, _loading = false;

  @override
  void dispose() { _loginCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final err = await ref.read(authProvider.notifier).login(_loginCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err), backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkProvider);
    final saved = ref.watch(authProvider.notifier).savedAccounts;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => ref.read(isDarkProvider.notifier).state = !isDark,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              _buildHeader(isDark),
              const SizedBox(height: 36),
              if (saved.isNotEmpty) ...[
                _buildSavedAccounts(saved, isDark),
                const SizedBox(height: 28),
              ],
              Text('Войти с паролем', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
              const SizedBox(height: 14),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildFormCard(isDark),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight,
                      child: TextButton(onPressed: null,
                        style: TextButton.styleFrom(disabledForegroundColor: AppColors.textMuted),
                        child: const Text('Забыли пароль?'))),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDark))
                          : const Text('Войти'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => context.go(AppRoutes.register1),
                      child: const Text('Зарегистрироваться'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(width: 50, height: 50,
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.terrain_rounded, color: Colors.white, size: 28)),
      const SizedBox(height: 20),
      Text('GIS Monitor', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight, letterSpacing: -0.5)),
      const SizedBox(height: 6),
      Text('Войдите в систему', style: TextStyle(fontSize: 15,
          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)),
    ],
  );

  Widget _buildSavedAccounts(List<SavedAccount> savedAccounts, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Сохранённые аккаунты', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(20)),
            child: Text('${savedAccounts.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent))),
        ]),
        const SizedBox(height: 10),
        ...savedAccounts.map((a) => _SavedAccountTile(
          account: a, isDark: isDark,
          onTap: () => ref.read(authProvider.notifier).quickLogin(a.login),
          onDelete: () { ref.read(authProvider.notifier).removeSavedAccount(a.login); setState(() {}); },
        )),
      ],
    );
  }

  Widget _buildFormCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextFormField(controller: _loginCtrl, textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Логин', hintText: 'Введите логин'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите логин' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _passCtrl, obscureText: _obscure, textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: 'Пароль', hintText: 'Введите пароль',
              suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
                onPressed: () => setState(() => _obscure = !_obscure))),
            validator: (v) => (v == null || v.length < 4) ? 'Минимум 4 символа' : null),
        ],
      ),
    );
  }
}

class _SavedAccountTile extends StatelessWidget {
  final SavedAccount account;
  final bool isDark;
  final VoidCallback onTap, onDelete;
  const _SavedAccountTile({required this.account, required this.isDark, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Row(
              children: [
                Container(width: 40, height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentDim], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(account.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.displayName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
                    Text(account.login, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                )),
                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.accent),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted), onPressed: onDelete, padding: const EdgeInsets.all(4), constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
