import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart' as image_picker;

import '../core/constants/app_colors.dart';

class NoteScanPage extends StatefulWidget {
  const NoteScanPage({super.key});

  @override
  State<NoteScanPage> createState() => _NoteScanPageState();
}

class _NoteScanPageState extends State<NoteScanPage> {
  final image_picker.ImagePicker _imagePicker = image_picker.ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  CameraController? _cameraController;
  bool _isLoadingCamera = true;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isLoadingCamera = false;
        _errorMessage = null;
        _cameraErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCamera = false;
        _errorMessage = 'Không thể mở camera lúc này.';
        _cameraErrorMessage = error.toString();
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

    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      final capturedFile = await controller.takePicture();
      await _recognizeAndReturn(capturedFile.path);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessing = false;
        _errorMessage = 'Không thể chụp ảnh lúc này.';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) {
      return;
    }

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: image_picker.ImageSource.gallery,
        imageQuality: 95,
      );

      if (pickedFile == null) {
        return;
      }

      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      await _recognizeAndReturn(pickedFile.path);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessing = false;
        _errorMessage = 'Không thể chọn ảnh từ thư viện.';
      });
    }
  }

  Future<void> _pickFromSystemCamera() async {
    if (_isProcessing) {
      return;
    }

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: image_picker.ImageSource.camera,
        imageQuality: 95,
      );

      if (pickedFile == null) {
        return;
      }

      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      await _recognizeAndReturn(pickedFile.path);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessing = false;
        _errorMessage = 'Không thể mở camera hệ thống.';
      });
    }
  }

  Future<void> _recognizeAndReturn(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final normalizedText = recognizedText.blocks
          .map((block) => block.text.trim())
          .where((text) => text.isNotEmpty)
          .join('\n');

      if (!mounted) {
        return;
      }

      if (normalizedText.isEmpty) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Không nhận diện được chữ từ ảnh này.';
        });
        return;
      }

      Navigator.pop(context, normalizedText);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessing = false;
        _errorMessage = 'OCR thất bại. Hãy thử lại với ảnh khác.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildBody(controller)),
            Positioned(
              top: 16,
              left: 16,
              child: _TopButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _isProcessing ? null : () => Navigator.pop(context),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: _TopButton(
                icon: Icons.photo_library_rounded,
                onTap: _isLoadingCamera || _isProcessing
                    ? null
                    : _pickFromGallery,
              ),
            ),
            if (_errorMessage != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 132,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: Center(
                child: IgnorePointer(
                  ignoring: _isLoadingCamera || _isProcessing,
                  child: GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.58),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text(
                          'Đang OCR ảnh...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CameraController? controller) {
    if (_isLoadingCamera) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Không mở được camera preview trong app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _cameraErrorMessage ??
                  'Thiết bị này vẫn có thể dùng camera hệ thống hoặc chọn ảnh từ thư viện.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickFromSystemCamera,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Chụp bằng camera hệ thống'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Chọn từ thư viện'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_cameraErrorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _cameraErrorMessage = null;
        });
      });
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1,
          height: controller.value.previewSize?.width ?? 1,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
