import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as ml;
import 'package:my_app/product_detail.dart';
import 'package:my_app/seller_profile_screen.dart';

class SmartScanScreen extends StatefulWidget {
  const SmartScanScreen({super.key});

  @override
  State<SmartScanScreen> createState() => _SmartScanScreenState();
}

class _SmartScanScreenState extends State<SmartScanScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  CameraController? _cameraController;

  bool _isReady = false;
  bool _isProcessing = false;
  bool _torchEnabled = false;
  String _status = 'ចង្អុលកាមេរ៉ាទៅទំនិញ រួចចុចថត';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera available');

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _cameraController = controller;
      await controller.initialize();

      if (!mounted) return;
      setState(() => _isReady = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'មិនអាចបើកកាមេរ៉ាបាន';
      });
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (_isProcessing ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'កំពុងវិភាគរូប...';
    });

    try {
      final photo = await controller.takePicture();
      await _processSelectedImage(photo);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _status = 'មិនអាចថតរូបបាន — សាកម្ដងទៀត';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 82,
    );
    if (image == null || !mounted) return;

    setState(() {
      _isProcessing = true;
      _status = 'កំពុងវិភាគរូប...';
    });

    await _processSelectedImage(image);
  }

  Future<void> _processSelectedImage(XFile image) async {
    ml.BarcodeScanner? scanner;
    try {
      scanner = ml.BarcodeScanner(formats: [ml.BarcodeFormat.qrCode]);
      final barcodes = await scanner.processImage(
        ml.InputImage.fromFilePath(image.path),
      );

      String? code;
      if (barcodes.isNotEmpty) {
        code = barcodes.first.rawValue ?? barcodes.first.displayValue;
      }

      if (code != null && code.trim().isNotEmpty) {
        final handled = await _handleSesanQr(code.trim());
        if (handled) return;
      }

      // No Sesan QR: return the chosen/captured image to Home.
      // Home will run the existing AI visual-search flow.
      if (!mounted) return;
      Navigator.pop(context, image);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _status = 'មិនអាចអានរូបនេះបាន — សាកម្ដងទៀត';
      });
    } finally {
      await scanner?.close();
    }
  }

  Future<bool> _handleSesanQr(String code) async {
    if (code.startsWith('product_id_')) {
      final productId = code.substring('product_id_'.length);
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (!mounted) return true;
      if (doc.exists) {
        final product = doc.data()!;
        product['id'] = doc.id;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
        return true;
      }
    }

    if (code.startsWith('shop_id_')) {
      final sellerId = code.substring('shop_id_'.length);
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();

      if (!mounted) return true;
      if (doc.exists) {
        final data = doc.data()!;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SellerProfileScreen(
              sellerId: sellerId,
              sellerName: (data['name'] ?? 'ហាង').toString(),
            ),
          ),
        );
        return true;
      }
    }

    return false;
  }

  Future<void> _toggleTorch() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    _torchEnabled = !_torchEnabled;
    await controller.setFlashMode(
      _torchEnabled ? FlashMode.torch : FlashMode.off,
    );

    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_isProcessing) return;

    try {
      final cameras = await availableCameras();
      if (cameras.length < 2) return;

      final current = _cameraController?.description;
      final next = cameras.firstWhere(
        (item) => item.lensDirection != current?.lensDirection,
        orElse: () => cameras.first,
      );

      await _cameraController?.dispose();

      final controller = CameraController(
        next,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraController = controller;
      await controller.initialize();

      if (mounted) {
        setState(() {
          _isReady = true;
          _torchEnabled = false;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isReady &&
                controller != null &&
                controller.value.isInitialized)
              CameraPreview(controller)
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Top controls
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      _circleButton(
                        icon: _torchEnabled
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        onTap: _toggleTorch,
                      ),
                      const SizedBox(width: 10),
                      _circleButton(
                        icon: Icons.flip_camera_ios_rounded,
                        onTap: _switchCamera,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Lazada-style guide text
            Positioned(
              top: 72,
              left: 24,
              right: 24,
              child: Text(
                'Point and snap\nsearch for the same',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      blurRadius: 5,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Siemreap',
                      fontSize: 12,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black87,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: _isProcessing ? null : _pickFromGallery,
                        child: Column(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.photo_library_outlined,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Album',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      GestureDetector(
                        onTap: _isProcessing ? null : _capturePhoto,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 5,
                            ),
                            color: Colors.white24,
                          ),
                          child: _isProcessing
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                              : const Center(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    child: SizedBox(
                                      width: 58,
                                      height: 58,
                                    ),
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(
                        width: 54,
                        height: 72,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
