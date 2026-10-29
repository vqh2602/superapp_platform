import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/animations/app_motion.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/app_theme.dart';
import '../../../../core/config/debug_mode_provider.dart';
import '../../../../core/config/endpoint_config.dart';
import '../../../../features/mini_app_catalog/data/mini_app_repository.dart';
import '../controllers/auth_controller.dart';

class MockLoginScreen extends ConsumerStatefulWidget {
  const MockLoginScreen({super.key});

  @override
  ConsumerState<MockLoginScreen> createState() => _MockLoginScreenState();
}

class _MockLoginScreenState extends ConsumerState<MockLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _endpointController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  int _versionTapCount = 0;
  DateTime? _lastTapTime;
  String? _localErrorMessage;

  @override
  void initState() {
    super.initState();
    final currentEndpoint = ref.read(backendEndpointProvider);
    _endpointController = TextEditingController(text: currentEndpoint.baseUrl);
    // Pre-fill default demo account for convenient testing
    _emailController.text = 'test_demo@example.com';
    _passwordController.text = 'demo-password-123';
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleVersionTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 4)) {
      _versionTapCount = 0;
    }
    _lastTapTime = now;
    _versionTapCount++;

    if (_versionTapCount >= 10) {
      _versionTapCount = 0;
      ref.read(debugModeNotifierProvider.notifier).enableDebug();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.developer_mode_rounded, color: Colors.greenAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chế độ Debug & Developer đã được kích hoạt!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (_versionTapCount >= 5) {
      final remaining = 10 - _versionTapCount;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nhấn thêm $remaining lần để bật chế độ Debug'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  void _handleVersionLongPress() {
    if (ref.read(debugModeNotifierProvider)) {
      ref.read(debugModeNotifierProvider.notifier).disableDebug();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tắt chế độ Debug thủ công.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _localErrorMessage = null;
    });
    ref.read(authStateProvider.notifier).clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final endpoint = _endpointController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Save configured endpoint
    await ref.read(backendEndpointProvider.notifier).setEndpoint(endpoint);

    // Call login API
    final success = await ref
        .read(authStateProvider.notifier)
        .login(email, password);

    if (success && mounted) {
      // Invalidate catalog to load fresh from newly configured backend
      ref.invalidate(dynamicCatalogProvider);
      ref.invalidate(catalogCategoriesProvider);
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isDebugActive = ref.watch(isDebugModeEnabledProvider);
    final errorMessage = _localErrorMessage ?? authState.errorMessage;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 40),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  padding: const EdgeInsets.all(18),
                                  color: AppTheme.primary,
                                  child: const Icon(
                                    Icons.lock_person_rounded,
                                    size: 44,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'SuperApp Platform',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Đăng nhập tài khoản & kết nối Backend Mini App',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF64748B).withValues(alpha: 0.9),
                          ),
                        ),
                      ],
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

                  // 1. Ô Endpoint Backend
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

                  // 2. Tài khoản & Mật khẩu
                  _buildSectionHeader('THÔNG TIN ĐĂNG NHẬP'),
                  const SizedBox(height: 6),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email / Tài khoản',
                      hintText: 'name@example.com',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
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
                        return 'Vui lòng nhập tài khoản hoặc email';
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
                      hintText: 'Nhập mật khẩu',
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
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Demo Credentials Quick Fill Chip
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF2563EB)),
                        label: const Text(
                          'Tài khoản mẫu: test_demo@example.com',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                        ),
                        backgroundColor: const Color(0xFFEFF6FF),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        onPressed: () {
                          _emailController.text = 'test_demo@example.com';
                          _passwordController.text = 'demo-password-123';
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Login Button
                  BouncingTap(
                    scaleFactor: 0.97,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _handleLogin,
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
                                'Đăng nhập SuperApp',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Register Button
                  BouncingTap(
                    scaleFactor: 0.97,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: authState.isLoading
                            ? null
                            : () {
                                context.push('/register');
                              },
                        icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                        label: const Text(
                          'Đăng ký tài khoản mới',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Debug / Version Tap
                  Center(
                    child: GestureDetector(
                      onTap: _handleVersionTap,
                      onLongPress: _handleVersionLongPress,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: Text(
                          'v${AppConfig.appVersion} • ${isDebugActive ? "DEBUG ACTIVE" : "Build 1.0.0+1"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDebugActive
                                ? const Color(0xFF10B981).withValues(alpha: 0.8)
                                : const Color(0xFF94A3B8).withValues(alpha: 0.45),
                            fontWeight: isDebugActive ? FontWeight.bold : FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
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
