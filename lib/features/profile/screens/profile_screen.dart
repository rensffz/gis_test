// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
// import '../../../models/app_models.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _fn  = TextEditingController();
  final _ln  = TextEditingController();
  final _org = TextEditingController();
  final _em  = TextEditingController();
  final _ph  = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider);
    if (u != null) {
      _loginCtrl.text = u.login;
      _fn.text  = u.firstName;
      _ln.text  = u.lastName;
      _org.text = u.organization;
      _em.text  = u.email;
      _ph.text  = u.phone;
    }
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _fn.dispose(); _ln.dispose(); _org.dispose(); _em.dispose(); _ph.dispose();
    super.dispose();
  }

  bool _validLogin(String v) => RegExp(r'^[a-zA-Z0-9_]{3,}$').hasMatch(v);
  bool _validEmail(String e)  => RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(e);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final u = ref.read(authProvider)!;
    final err = await ref.read(authProvider.notifier).updateProfile(
      u.copyWith(
        login:        _loginCtrl.text.trim(),
        firstName:    _fn.text.trim(),
        lastName:     _ln.text.trim(),
        organization: _org.text.trim(),
        email:        _em.text.trim(),
        phone:        _ph.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      showAppSnackbar(context, err, isError: true);
    } else {
      showAppSnackbar(context, 'Профиль сохранён');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user   = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: GisAppBar(title: 'Профиль', showDrawer: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(children: [
            // ── Avatar + login display ────────────────────────
            Center(child: Column(children: [
              Container(width: 76, height: 76,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDim],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle),
                child: Center(child: Text(
                  user?.initials ?? '?',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)))),
              const SizedBox(height: 8),
              Text(
                '@${user?.login ?? ''}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ])),
            const SizedBox(height: 20),

            // ── Account section ───────────────────────────────
            _sectionLabel('Аккаунт', isDark),
            const SizedBox(height: 6),
            AppCard(child: Column(children: [
              // Editable login field
              TextFormField(
                controller: _loginCtrl,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: _dec('Логин', 'ivan_petrov', isDark),
                style: TextStyle(color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Введите логин';
                  if (!_validLogin(v.trim())) return 'Только буквы, цифры и _, минимум 3 символа';
                  return null;
                },
              ),
            ])),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => const _ChangePasswordDialog()),
              icon: const Icon(Icons.lock_outline_rounded, size: 16),
              label: const Text('Сменить пароль'),
            ),
            const SizedBox(height: 12),

            // ── Personal info ─────────────────────────────────
            _sectionLabel('Личные данные', isDark),
            const SizedBox(height: 6),
            AppCard(child: Column(children: [
              _field(_fn,  'Имя',         isDark, req: true),
              const SizedBox(height: 12),
              _field(_ln,  'Фамилия',     isDark, req: true),
              const SizedBox(height: 12),
              _field(_org, 'Организация', isDark, req: true),
            ])),
            const SizedBox(height: 12),

            // ── Contacts ──────────────────────────────────────
            _sectionLabel('Контакты', isDark),
            const SizedBox(height: 6),
            AppCard(child: Column(children: [
              TextFormField(
                controller: _em,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('E-mail', 'example@mail.com', isDark),
                style: TextStyle(color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Введите email';
                  if (!_validEmail(v.trim())) return 'Некорректный email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _field(_ph, 'Телефон', isDark, req: false, type: TextInputType.phone),
            ])),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDark))
                  : const Text('Сохранить профиль'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8,
          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
      ),
    ),
  );

  Widget _field(TextEditingController c, String l, bool isDark,
      {bool req = true, TextInputType? type}) =>
      TextFormField(
        controller: c,
        keyboardType: type,
        textCapitalization: TextCapitalization.words,
        decoration: _dec(l, '', isDark),
        style: TextStyle(color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
        validator: req ? (v) => (v == null || v.trim().isEmpty) ? 'Заполните поле' : null : null,
      );

  InputDecoration _dec(String l, String h, bool isDark) => InputDecoration(
    labelText: l, hintText: h,
    labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
  );
}

// ── Change password dialog ──────────────────────────────────────
class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();
  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _cur  = TextEditingController();
  final _newP = TextEditingController();
  final _cnf  = TextEditingController();
  bool _saving = false;
  bool _showCur = false, _showNew = false, _showCnf = false;

  @override
  void dispose() {
    _cur.dispose(); _newP.dispose(); _cnf.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await ref.read(authProvider.notifier).changePassword(_cur.text, _newP.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      showAppSnackbar(context, err, isError: true);
    } else {
      Navigator.pop(context);
      showAppSnackbar(context, 'Пароль успешно изменён');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Смена пароля', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _pwdField(_cur,  'Текущий пароль',  _showCur,  () => setState(() => _showCur  = !_showCur)),
          const SizedBox(height: 12),
          _pwdField(_newP, 'Новый пароль',     _showNew,  () => setState(() => _showNew  = !_showNew),
            extra: (v) => (v != null && v.isNotEmpty && v.length < 6) ? 'Минимум 6 символов' : null),
          const SizedBox(height: 12),
          _pwdField(_cnf,  'Подтверждение',    _showCnf,  () => setState(() => _showCnf  = !_showCnf),
            extra: (v) => v != _newP.text ? 'Пароли не совпадают' : null),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Сохранить'),
        ),
      ],
    );
  }

  Widget _pwdField(TextEditingController c, String label, bool show, VoidCallback toggle,
      {String? Function(String?)? extra}) =>
      TextFormField(
        controller: c,
        obscureText: !show,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          suffixIcon: IconButton(
            icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 17, color: AppColors.textMuted),
            onPressed: toggle,
          ),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Заполните поле';
          return extra?.call(v);
        },
      );
}
