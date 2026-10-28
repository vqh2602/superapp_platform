import 'package:flutter/material.dart';
import 'superapp_bridge_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SuperAppBridgeClient().init(appId: 'flutter_web_demo');
  runApp(const FlutterWebMiniApp());
}

class FlutterWebMiniApp extends StatelessWidget {
  const FlutterWebMiniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Web Mini App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF02569B),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final bridge = SuperAppBridgeClient();
  String _userName = 'Chưa đăng nhập';
  String _batteryText = '--%';

  @override
  void initState() {
    super.initState();
    _fetchBattery();
  }

  Future<void> _fetchBattery() async {
    try {
      final res = await bridge.invoke<Map<String, dynamic>>('device.getBatteryInfo');
      setState(() {
        _batteryText = '${res['batteryLevel']}% (${res['isCharging'] == true ? 'Sạc' : 'Pin'})';
      });
    } catch (_) {}
  }

  Future<void> _login() async {
    try {
      final auth = await bridge.invoke<Map<String, dynamic>>('auth.requestCode', {'scopes': ['user.profile']});
      final profile = await bridge.invoke<Map<String, dynamic>>('user.getProfile');
      setState(() {
        _userName = profile['name'] ?? 'Người dùng';
      });
      await bridge.invoke('ui.showToast', {'message': 'Xin chào ${_userName}!'});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _scanQR() async {
    try {
      final res = await bridge.invoke<Map<String, dynamic>>('device.scanQRCode');
      await bridge.invoke('ui.showToast', {'message': 'Mã QR: ${res['content']}'});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Web Mini App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQR,
            tooltip: 'Quét QR',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => bridge.invoke('navigation.close'),
            tooltip: 'Đóng',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flutter_dash, size: 72, color: Color(0xFF02569B)),
              const SizedBox(height: 16),
              Text('Tài khoản: $_userName', style: Theme.of(context).textTheme.titleLarge),
              Text('Pin: $_batteryText', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Đăng nhập SSO'),
                onPressed: _login,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
