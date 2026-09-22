import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_app/localization/app_translations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:my_app/controllers/auth_controller.dart';
import 'package:my_app/forgot_password_screen.dart';
import 'package:my_app/home_screen.dart';
import 'package:my_app/product_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart' hide UserService;
import 'account_deletion_service.dart';
import 'auth_session_store.dart';
import 'google_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberPhone = false;
  bool _useEmailLogin = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_phone') ?? false;
    if (remember) {
      final phone = prefs.getString('remembered_phone') ?? '';
      if (mounted) {
        setState(() {
          _phoneController.text = phone;
          _rememberPhone = true;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final result = await GoogleAuthService.signIn();
      if (result == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await Get.find<AuthController>().loginWithUid(result.uid);

      if (!mounted) return;
      _showSnackBar(
        result.isNewUser
            ? _accountText(
                km: '✅ បានបង្កើតគណនី Google រួចរាល់',
                en: '✅ Google account created',
              )
            : _accountText(
                km: '✅ ចូលដោយ Google បានជោគជ័យ',
                en: '✅ Signed in with Google',
              ),
      );
      Get.offAllNamed('/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'account-pending-deletion'
          ? _accountText(
              km: 'គណនីនេះកំពុងរង់ចាំការលុប។ សូមប្រើវិធីចូលគណនីចាស់ដើម្បីស្ដារវិញសិន។',
              en: 'This account is pending deletion. Restore it with your existing sign-in method first.',
            )
          : (e.message ?? e.code);
      _showSnackBar('⚠️ $message', isError: true);
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          _accountText(
            km: 'មិនអាចចូលដោយ Google បាន៖ $e',
            en: 'Could not sign in with Google: $e',
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    UserService.clearCache();
    setState(() => _isLoading = true);

    try {
      final authResult = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = authResult.user;
      if (firebaseUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Account not found.',
        );
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'account-data-missing',
          message: 'Sesan account data was not found.',
        );
      }

      final userData = userDoc.data()!;
      if (userData['isDeleted'] == true ||
          userData['accountStatus'] == 'pending_deletion') {
        final canContinue = await _handleDeletedAccount(userDoc.id, userData);
        if (!canContinue) {
          await FirebaseAuth.instance.signOut();
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      await AuthSessionStore.save(
        email: email,
        password: password,
        uid: firebaseUser.uid,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .set({
        'email': email,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', firebaseUser.uid);
      await prefs.setString(
        'user_name',
        (userData['name'] ?? firebaseUser.displayName ?? '').toString(),
      );
      await prefs.setString('user_phone', (userData['phone'] ?? '').toString());
      await prefs.setString(
        'user_photo',
        (userData['photoUrl'] ?? firebaseUser.photoURL ?? '').toString(),
      );
      await prefs.setString(
        'user_role',
        (userData['role'] ?? 'user').toString(),
      );
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_guest', false);

      await Get.find<AuthController>().loginWithUid(firebaseUser.uid);

      if (!mounted) return;
      _showSnackBar(
        _accountText(
          km: '✅ ចូលដោយ Email បានជោគជ័យ',
          en: '✅ Signed in with Email',
        ),
      );
      Get.offAllNamed('/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = (e.code == 'user-not-found' ||
              e.code == 'invalid-credential' ||
              e.code == 'wrong-password')
          ? _accountText(
              km: 'Email ឬលេខសម្ងាត់មិនត្រឹមត្រូវ',
              en: 'Incorrect email or password',
            )
          : (e.message ?? e.code);
      _showSnackBar('⚠️ $message', isError: true);
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          _accountText(
            km: 'មិនអាចចូលដោយ Email បាន៖ $e',
            en: 'Could not sign in with Email: $e',
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final rawPhone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    // Keep the existing session and settings until the new Firebase login
    // succeeds. Clearing preferences here can turn a temporary login failure
    // into an unexpected logout.
    UserService.clearCache();

    setState(() => _isLoading = true);
    // ... កូដដដែល ...

    // ✅ បង្កើតទម្រង់លេខ ២ formats
    final phoneWith855 = rawPhone.startsWith('+855')
        ? rawPhone
        : rawPhone.startsWith('0')
        ? '+855${rawPhone.substring(1)}'
        : '+855$rawPhone';

    final phoneWithZero = rawPhone.startsWith('+855')
        ? '0${rawPhone.substring(4)}'
        : rawPhone.startsWith('0')
        ? rawPhone
        : '0$rawPhone';

    try {
      // ✅ ស្វែងរក user ក្នុង Firestore
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', whereIn: [phoneWith855, phoneWithZero])
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('❌ ${'account_not_found'.tr}', isError: true);
        }
        return;
      }

      final userDoc = query.docs.first;
      final userData = userDoc.data();
      final dbPassword = (userData['password'] ?? '').toString().trim();

      if (dbPassword != password) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('🔑 ${'wrong_password'.tr}', isError: true);
        }
        return;
      }

      if (userData['isDeleted'] == true ||
          userData['accountStatus'] == 'pending_deletion') {
        final canContinue = await _handleDeletedAccount(userDoc.id, userData);
        if (!canContinue) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      // Firebase callable functions require a real Firebase Auth session.
      // Sesan accounts use the phone number as a private synthetic email.
      final authEmail = "${phoneWith855.replaceAll('+', '')}@sesan.app";
      final authResult = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      // Never continue if Firestore and Firebase Authentication point to
      // different accounts.
      if (authResult.user?.uid != userDoc.id) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'user-mismatch',
          message: 'The Sesan account does not match Firebase Authentication.',
        );
      }

      await AuthSessionStore.save(
        email: authEmail,
        password: password,
        uid: userDoc.id,
      );

      // ✅ ១. Update lastLogin ទៅ Firebase (ថែមត្រង់នេះ)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .update({'lastLogin': FieldValue.serverTimestamp()});
      // ✅ Save ព័ត៌មាន user ក្នុង SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', userDoc.id);
      await prefs.setString('user_name', userData['name'] ?? '');
      await prefs.setString('user_phone', userData['phone'] ?? '');
      await prefs.setString('user_photo', userData['photoUrl'] ?? '');
      await prefs.setString('user_role', userData['role'] ?? 'seller');
      await prefs.setBool('is_logged_in', true);

      // ✅ Save phone ប្រសិនបើ remember
      if (_rememberPhone) {
        await prefs.setString('remembered_phone', rawPhone);
        await prefs.setBool('remember_phone', true);
      } else {
        await prefs.remove('remembered_phone');
        await prefs.setBool('remember_phone', false);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('✅ ${'login_success'.tr}');

        // 🎯 ថែមជួរនេះ៖ ដាស់ AuthController ឱ្យដឹងថាមាន User បាន Login ហើយ
        await Get.find<AuthController>().loginWithUid(userDoc.id);

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          // 🎯 កែមកប្រើ Get.offAllNamed ជំនួស Navigator ដើម្បីឱ្យ Obx ក្នុង main.dart ដំណើរការស្របគ្នា
          Get.offAllNamed('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('⚠️ ${'error'.tr}: $e', isError: true);
      }
    }
  }

  String _accountText({required String km, required String en}) {
    final code = Get.locale?.languageCode ??
        Localizations.maybeLocaleOf(context)?.languageCode ??
        'km';
    return code == 'en' ? en : km;
  }

  Future<bool> _handleDeletedAccount(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    final deadlineValue = userData['restoreDeadline'];
    final deadline = deadlineValue is Timestamp
        ? deadlineValue.toDate()
        : DateTime.now().subtract(const Duration(seconds: 1));

    if (!DateTime.now().isBefore(deadline)) {
      await AccountDeletionService.markExpired(userId);
      if (mounted) {
        _showSnackBar(
          _accountText(
            km: 'រយៈពេលស្ដារគណនី 15 ថ្ងៃបានផុតកំណត់ហើយ',
            en: 'The 15-day account recovery period has expired',
          ),
          isError: true,
        );
      }
      return false;
    }

    final remaining = deadline.difference(DateTime.now()).inDays + 1;
    if (!mounted) return false;
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_accountText(km: 'ស្ដារគណនីវិញ?', en: 'Restore your account?')),
        content: Text(
          _accountText(
            km: 'គណនីនេះកំពុងរង់ចាំការលុប។ នៅសល់ប្រហែល $remaining ថ្ងៃសម្រាប់ស្ដារគណនី និង Content ទាំងអស់វិញ។',
            en: 'This account is pending deletion. About $remaining days remain to restore the account and all archived content.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_accountText(km: 'មិនទាន់ស្ដារ', en: 'Not now')),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.restore),
            label: Text(_accountText(km: 'ស្ដារគណនី', en: 'Restore account')),
          ),
        ],
      ),
    );

    if (restore != true) return false;

    try {
      await AccountDeletionService.restoreOwnedContent(userId);
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'accountStatus': 'active',
        'isDeleted': false,
        'restoredAt': FieldValue.serverTimestamp(),
        'deletedAt': FieldValue.delete(),
        'restoreDeadline': FieldValue.delete(),
        'archivedContentCount': FieldValue.delete(),
        'deletionExpiredAt': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (mounted) {
        _showSnackBar(
          _accountText(
            km: '✅ បានស្ដារគណនី និង Content រួចរាល់',
            en: '✅ Account and content restored',
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          _accountText(
            km: 'មិនអាចស្ដារគណនីបាន៖ $e',
            en: 'Could not restore account: $e',
          ),
          isError: true,
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: LanguageSwitcher(),
                  ),
                  const SizedBox(height: 20),

                  // ── Logo ──────────────────────────────────
                  // 🎯 ស្វែងរកកន្លែងបង្ហាញ Icon រូបកាបូប ហើយជំនួសដោយកូដនេះ
                  Container(
                    width: 130, // ទំហំមេអាចសារ៉េតាមចិត្ត
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                      // 🎯 ប្រើ AssetImage ដើម្បីទាញយក sesan_icon.jpg
                      image: const DecorationImage(
                        image: AssetImage('assets/sesan_icon.jpg'),
                        fit: BoxFit.cover, // ឱ្យរូបភាពពេញរង្វង់ស្អាត
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SESAN APP',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'login_subtitle'.tr,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() => _useEmailLogin = false),
                            icon: const Icon(Icons.phone_android),
                            label: Text(
                              _accountText(km: 'លេខទូរស័ព្ទ', en: 'Phone'),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: !_useEmailLogin
                                  ? Colors.white
                                  : Colors.transparent,
                              foregroundColor: !_useEmailLogin
                                  ? Colors.green[700]
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() => _useEmailLogin = true),
                            icon: const Icon(Icons.email_outlined),
                            label: const Text('Email'),
                            style: TextButton.styleFrom(
                              backgroundColor: _useEmailLogin
                                  ? Colors.white
                                  : Colors.transparent,
                              foregroundColor: _useEmailLogin
                                  ? Colors.green[700]
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (_useEmailLogin)
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'example@gmail.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) {
                          return _accountText(
                            km: 'សូមបញ្ចូល Email',
                            en: 'Email is required',
                          );
                        }
                        if (!value.contains('@') ||
                            !value.contains('.') ||
                            value.startsWith('@') ||
                            value.endsWith('@')) {
                          return _accountText(
                            km: 'Email មិនត្រឹមត្រូវ',
                            en: 'Invalid email',
                          );
                        }
                        return null;
                      },
                    )
                  else
                    _buildTextField(
                      controller: _phoneController,
                      label: 'phone'.tr,
                      hint: 'phone_hint'.tr,
                      icon: Icons.phone_android,
                      isNumber: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'phone_required'.tr;
                        if (!RegExp(r'^(0|\+855)[0-9]{8,9}$').hasMatch(v)) {
                          return 'phone_invalid'.tr;
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),

                  // ── លេខសម្ងាត់ ────────────────────────────
                  _buildTextField(
                    controller: _passwordController,
                    label: 'password'.tr,
                    hint: 'password_hint'.tr,
                    icon: Icons.lock_outline,
                    isPassword: true,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'password_required'.tr;
                      if (v.length < 6)
                        return 'password_min_6'.tr;
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── Remember + Forgot ─────────────────────
                  if (!_useEmailLogin)
                    Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: () => setState(
                            () => _rememberPhone = !_rememberPhone,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _rememberPhone,
                                onChanged: (v) => setState(
                                  () => _rememberPhone = v ?? false,
                                ),
                                activeColor: Colors.green,
                                visualDensity: VisualDensity.compact,
                              ),
                              Expanded(
                                child: Text(
                                  'remember_phone'.tr,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        flex: 2,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'forgot_password'.tr,
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── ប៊ូតុងចូល ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_useEmailLogin
                              ? _handleEmailLogin
                              : _handleLogin),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'login'.tr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          _accountText(km: 'ឬ', en: 'OR'),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleLogin,
                      icon: const Text(
                        'G',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                      label: Text(
                        _accountText(
                          km: 'បន្តជាមួយ Google',
                          en: 'Continue with Google',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── ចុះឈ្មោះ ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'no_account'.tr,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/signup'),
                        child: Text(
                          'register_here'.tr,
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ── ប៊ូតុងចូលមើលសិន ─────────────────────────
                  // ── ប៊ូតុងចូលមើលសិន ─────────────────────────
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Get.find<AuthController>().loginAsGuest();
                      // 🎯 កែត្រង់នេះ៖ បញ្ជូន guestMode: true ទៅឱ្យ HomeScreen ផងដើម្បីកុំឱ្យវាច្រឡំ
                      Get.offAllNamed('/home-guest'); // Guest mode
                    },
                    icon: const Icon(Icons.person_outline, color: Colors.green),
                    label: Text(
                      'continue_guest'.tr,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      side: const BorderSide(color: Colors.green, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30), // រាងមូល
                      ),
                      backgroundColor: Colors.green.shade50.withOpacity(
                        0.3,
                      ), // ពណ៌ផ្ទៃថ្លាបៃតងខ្ចី
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? !_isPasswordVisible : false,
      keyboardType:
          keyboardType ?? (isNumber ? TextInputType.phone : TextInputType.text),
      autocorrect: false,
      textCapitalization: TextCapitalization.none,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey[600],
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              )
            : null,
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
