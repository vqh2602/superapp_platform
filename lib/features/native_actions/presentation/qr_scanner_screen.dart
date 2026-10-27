import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  const QrScannerScreen({
    super.key,
    this.title = 'Quét mã QR & Mã vạch',
    this.subtitle = 'Hướng camera vào mã QR hoặc mã vạch cần quét',
  });

  static Future<Map<String, dynamic>?> open(BuildContext context) {
    return Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const QrScannerScreen(),
      ),
    );
  }

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isScanned = false;
  bool _isTorchOn = false;
  bool _hasCameraError = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _controller.start();
      } catch (e) {
        debugPrint('MobileScanner camera start error (simulator or camera unavailable): $e');
        if (mounted) {
          setState(() {
            _hasCameraError = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    try {
      _controller.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

    _isScanned = true;
    HapticFeedback.mediumImpact();

    final result = {
      'content': barcode.rawValue!,
      'format': barcode.format.name.toUpperCase(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isMock': false,
    };

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      BarcodeCapture? capture;
      try {
        capture = await _controller.analyzeImage(pickedFile.path);
      } catch (_) {}

      final barcode = capture?.barcodes.firstOrNull;

      if (barcode != null && barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop({
          'content': barcode.rawValue!,
          'format': barcode.format.name.toUpperCase(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'isMock': false,
        });
      } else {
        if (!mounted) return;
        // Prompt user if analyzer didn't detect pattern from image
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy mã hợp lệ trong ảnh, bạn có thể nhập mã thủ công'),
            backgroundColor: Colors.amber,
          ),
        );
        _showManualInputDialog();
      }
    } catch (e) {
      if (!mounted) return;
      _showManualInputDialog();
    }
  }

  void _showManualInputDialog() {
    final textController = TextEditingController(text: '8935001700125');
    String selectedFormat = 'EAN_13';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF18181B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhập mã thủ công',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dành cho môi trường giả lập (Simulator) hoặc nơi camera không khả dụng.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF27272A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      hintText: 'Nhập nội dung mã QR hoặc mã vạch...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Định dạng: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: selectedFormat,
                        dropdownColor: const Color(0xFF27272A),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'QR_CODE', child: Text('QR Code')),
                          DropdownMenuItem(value: 'EAN_13', child: Text('EAN-13')),
                          DropdownMenuItem(value: 'CODE_128', child: Text('Code-128')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedFormat = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Huỷ'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final code = textController.text.trim();
                            if (code.isNotEmpty) {
                              Navigator.pop(ctx);
                              Navigator.pop(this.context, {
                                'content': code,
                                'format': selectedFormat,
                                'timestamp': DateTime.now().millisecondsSinceEpoch,
                                'isMock': false,
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Xác nhận'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorFallback(String errorDesc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 56, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            const Text(
              'Camera không khả dụng',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Thiết bị hoặc quyền camera chưa sẵn sàng ($errorDesc).\nBạn có thể quét ảnh từ Thư viện hoặc Nhập mã bên dưới.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Chọn ảnh từ Thư viện'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: _pickImageFromGallery,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.edit, color: Colors.white70),
              label: const Text('Nhập mã thủ công', style: TextStyle(color: Colors.white70)),
              onPressed: _showManualInputDialog,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Viewfinder or Fallback
          if (_hasCameraError)
            _buildErrorFallback('Camera không có sẵn trên máy ảo')
          else
            MobileScanner(
              controller: _controller,
              onDetect: _onBarcodeDetected,
              onDetectError: (error, stackTrace) {
                debugPrint('MobileScanner onDetectError: $error');
                if (mounted && !_hasCameraError) {
                  setState(() => _hasCameraError = true);
                }
              },
              errorBuilder: (context, error) {
                return _buildErrorFallback(error.errorCode.name);
              },
            ),

          // 2. Scan Reticle & Overlay Cutout
          if (!_hasCameraError)
            LayoutBuilder(
              builder: (context, constraints) {
                final scanSize = constraints.maxWidth * 0.72;
                return Center(
                  child: SizedBox(
                    width: scanSize,
                    height: scanSize,
                    child: Stack(
                      children: [
                        // Target Box Border
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.8), width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        // Animated scanning line
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            return Positioned(
                              top: _animController.value * (scanSize - 4),
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blueAccent.withValues(alpha: 0.1),
                                      Colors.cyanAccent,
                                      Colors.blueAccent.withValues(alpha: 0.1),
                                    ],
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.cyanAccent,
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // 3. Header Bar with Back Button & Instructions
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. Bottom Controls Toolbar
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Flashlight / Torch toggle
                  IconButton(
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on : Icons.flash_off,
                      color: _isTorchOn ? Colors.amberAccent : Colors.white70,
                      size: 26,
                    ),
                    onPressed: () async {
                      try {
                        await _controller.toggleTorch();
                        setState(() => _isTorchOn = !_isTorchOn);
                      } catch (_) {}
                    },
                    tooltip: 'Bật/Tắt đèn Flash',
                  ),
                  // Switch camera
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white70, size: 26),
                    onPressed: () async {
                      try {
                        await _controller.switchCamera();
                      } catch (_) {}
                    },
                    tooltip: 'Đổi camera trước/sau',
                  ),
                  // Pick image from gallery to scan
                  IconButton(
                    icon: const Icon(Icons.photo_library, color: Colors.white70, size: 26),
                    onPressed: _pickImageFromGallery,
                    tooltip: 'Quét mã từ Thư viện ảnh',
                  ),
                  // Manual input
                  IconButton(
                    icon: const Icon(Icons.keyboard, color: Colors.white70, size: 26),
                    onPressed: _showManualInputDialog,
                    tooltip: 'Nhập mã thủ công',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
