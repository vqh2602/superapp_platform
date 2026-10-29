import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/app_theme.dart';
import '../../../../core/config/endpoint_config.dart';
import '../../../../features/mini_app_catalog/data/mini_app_repository.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _endpointController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _localErrorMessage;

  @override
  void initState() {
    super.initState();
    final currentEndpoint = ref.read(backendEndpointProvider);
    _endpointController = TextEditingController(text: currentEndpoint.baseUrl);
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() {
      _localErrorMessage = null;
    });
    ref.read(authStateProvider.notifier).clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final endpoint = _endpointController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      setState(() {
        _localErrorMessage = 'Mật khẩu xác nhận không khớp.';
      });
      return;
    }

    // Save configured endpoint
    await ref.read(backendEndpointProvider.notifier).setEndpoint(endpoint);

    // Call register API
    final success = await ref.read(authStateProvider.notifier).register(
          email: email,
          password: password,
          displayName: name,
        );

    if (success && mounted) {
      // Invalidate catalog to load fresh from newly configured backend
      ref.invalidate(dynamicCatalogProvider);
      ref.invalidate(catalogCategoriesProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Đăng ký tài khoản thành công! Chào mừng $name.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final errorMessage = _localErrorMessage ?? authState.errorMessage;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => context.go('/login'),
        ),
        title: const Text(
          'Đăng ký tài khoản',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Header
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            padding: const EdgeInsets.all(16),
                            color: AppTheme.primary,
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Tạo tài khoản SuperApp',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Tài khoản đồng bộ trực tiếp với Backend Registry',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF64748B).withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error Banner
                  if (errorMessage != null && errorMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 20, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. Endpoint Field
                  _buildSectionHeader('CẤU HÌNH HỆ THỐNG'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _endpointController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Backend Endpoint URL',
                      hintText: 'https://superappplatfrom.alwaysdata.net',
                      prefixIcon: const Icon(Icons.dns_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.restore_rounded, size: 20),
                        tooltip: 'Đặt lại mặc định',
                        onPressed: () {
                          setState(() {
                            _endpointController.text = AppConfig.defaultBaseUrl;
                          });
                        },
                      ),
                      helperText: 'Nhập URL endpoint riêng hoặc bấm chọn nhanh bên dưới',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập Backend Endpoint';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // Nút chọn nhanh Endpoint
                  Builder(
                    builder: (context) {
                      final currentText = _endpointController.text.trim();
                      final isAlwaysdata = currentText == EndpointConfig.alwaysdataEndpoint ||
                          EndpointConfig.normalize(currentText) == EndpointConfig.alwaysdataEndpoint;
                      final isLocalhost = currentText == EndpointConfig.localhostEndpoint ||
                          EndpointConfig.normalize(currentText) == EndpointConfig.localhostEndpoint;

                      return Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Chọn nhanh:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ActionChip(
                            avatar: Icon(
                              Icons.cloud_rounded,
                              size: 16,
                              color: isAlwaysdata ? Colors.white : const Color(0xFF16A34A),
                            ),
                            label: const Text('Alwaysdata (Cloud)'),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isAlwaysdata ? FontWeight.bold : FontWeight.w500,
                              color: isAlwaysdata ? Colors.white : const Color(0xFF0F172A),
                            ),
                            backgroundColor: isAlwaysdata ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9),
                            side: BorderSide(
                              color: isAlwaysdata ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                            ),
                            onPressed: () {
                              setState(() {
                                _endpointController.text = EndpointConfig.alwaysdataEndpoint;
                              });
                            },
                          ),
                          ActionChip(
                            avatar: Icon(
                              Icons.computer_rounded,
                              size: 16,
                              color: isLocalhost ? Colors.white : const Color(0xFF0284C7),
                            ),
                            label: const Text('Localhost (3000)'),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isLocalhost ? FontWeight.bold : FontWeight.w500,
                              color: isLocalhost ? Colors.white : const Color(0xFF0F172A),
                            ),
                            backgroundColor: isLocalhost ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                            side: BorderSide(
                              color: isLocalhost ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                            ),
                            onPressed: () {
                              setState(() {
                                _endpointController.text = EndpointConfig.localhostEndpoint;
                              });
                            },
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // 2. Profile & Credentials Fields
                  _buildSectionHeader('THÔNG TIN TÀI KHOẢN'),
                  const SizedBox(height: 6),

                  // Display Name
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Họ và tên / Tên hiển thị',
                      hintText: 'Ví dụ: Alice hoặc Nguyễn Văn A',
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập tên hiển thị';
                      }
                      if (val.trim().length > 128) {
                        return 'Tên không vượt quá 128 ký tự';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email (Tài khoản)',
                      hintText: 'name@example.com',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập email';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'Định dạng email không hợp lệ';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      hintText: 'Tối thiểu 8 ký tự',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      helperText: 'Tối thiểu 8 ký tự theo tiêu chuẩn bảo mật',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      if (val.length < 8) {
                        return 'Mật khẩu phải có ít nhất 8 ký tự';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Confirm Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu',
                      hintText: 'Nhập lại mật khẩu ở trên',
                      prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Vui lòng xác nhận mật khẩu';
                      }
                      if (val != _passwordController.text) {
                        return 'Mật khẩu xác nhận không khớp';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Đăng ký tài khoản mới',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Navigate back to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Đã có tài khoản?',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          'Đăng nhập ngay',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.8,
      ),
    );
  }
}
