import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as mlkit;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/constants/app_colors.dart';
import '../core/services/api_service.dart';
import '../data/models/google_book_search_result.dart';
import '../data/models/user_model.dart';

class BarcodeScanPage extends StatefulWidget {
  const BarcodeScanPage({
    super.key,
    required this.user,
    this.token,
  });

  final UserModel user;
  final String? token;

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  final mlkit.BarcodeScanner _imageBarcodeScanner = mlkit.BarcodeScanner(
    formats: [
      mlkit.BarcodeFormat.ean13,
      mlkit.BarcodeFormat.ean8,
      mlkit.BarcodeFormat.upca,
      mlkit.BarcodeFormat.upce,
      mlkit.BarcodeFormat.code128,
      mlkit.BarcodeFormat.code39,
      mlkit.BarcodeFormat.code93,
      mlkit.BarcodeFormat.itf,
    ],
  );
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isResolving = false;
  bool _torchEnabled = false;
  String? _message;
  String? _lastScannedCode;

  @override
  void dispose() {
    _imageBarcodeScanner.close();
    _scannerController.dispose();
    super.dispose();
  }

  String? _normalizeBarcode(String? rawValue) {
    final normalized = rawValue?.replaceAll(RegExp(r'[^0-9Xx]'), '') ?? '';
    if (normalized.length < 8) {
      return null;
    }

    return normalized.toUpperCase();
  }

  Barcode? _pickFirstValidBarcode(Iterable<Barcode> barcodes) {
    for (final barcode in barcodes) {
      if (barcode.rawValue?.trim().isNotEmpty ?? false) {
        return barcode;
      }
    }

    return null;
  }

  Future<void> _resumeScannerIfNeeded() async {
    final state = _scannerController.value;
    if (!state.isInitialized || state.isRunning) {
      return;
    }

    await _scannerController.start();
  }

  Future<void> _resolveBarcode(
    String normalizedBarcode, {
    bool shouldResumeScanner = true,
  }) async {
    setState(() {
      _isResolving = true;
      _message = null;
      _lastScannedCode = normalizedBarcode;
    });

    try {
      final query = Uri.encodeQueryComponent('isbn:$normalizedBarcode');
      final result = await _apiService.get(
        '/books/search?query=$query',
        headers: widget.token == null
            ? null
            : {'Authorization': 'Bearer ${widget.token}'},
      );

      final data = result['data'] as Map<String, dynamic>? ?? const {};
      final items = data['items'];
      final books = items is List
          ? items
                .whereType<Map>()
                .map(
                  (item) => GoogleBookSearchResult.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((book) => book.title.trim().isNotEmpty)
                .toList()
          : const <GoogleBookSearchResult>[];

      if (!mounted) {
        return;
      }

      if (books.isEmpty) {
        setState(() {
          _message = 'No book found for barcode $normalizedBarcode.';
          _isResolving = false;
        });
        if (shouldResumeScanner) {
          await _resumeScannerIfNeeded();
        }
        return;
      }

      Navigator.pop(context, books.first);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
        _isResolving = false;
      });
      if (shouldResumeScanner) {
        await _resumeScannerIfNeeded();
      }
    }
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_isResolving) {
      return;
    }

    final barcode = _pickFirstValidBarcode(capture.barcodes);
    final normalizedBarcode = _normalizeBarcode(barcode?.rawValue);

    if (normalizedBarcode == null) {
      if (!mounted) return;
      setState(() {
        _message = 'No valid barcode detected.';
      });
      return;
    }

    await _scannerController.stop();
    await _resolveBarcode(normalizedBarcode);
  }

  Future<void> _pickBarcodeImage() async {
    if (_isResolving) {
      return;
    }

    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (pickedImage == null) {
      return;
    }

    try {
      final inputImage = mlkit.InputImage.fromFilePath(pickedImage.path);
      final detectedBarcodes = await _imageBarcodeScanner.processImage(
        inputImage,
      );
      final rawValue = detectedBarcodes
          .map((barcode) => barcode.rawValue?.trim())
          .whereType<String>()
          .firstWhere(
            (value) => value.isNotEmpty,
            orElse: () => '',
          );
      final normalizedBarcode = _normalizeBarcode(
        rawValue.isEmpty ? null : rawValue,
      );

      if (normalizedBarcode == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _message = 'No barcode found in the selected image.';
          _isResolving = false;
        });
        return;
      }

      await _resolveBarcode(
        normalizedBarcode,
        shouldResumeScanner: false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
        _isResolving = false;
      });
    }
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    if (!mounted) return;
    setState(() {
      _torchEnabled = !_torchEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _handleDetection,
            ),
          ),
          const Positioned.fill(child: _BarcodeScannerOverlay()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      _ScannerIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      _ScannerIconButton(
                        icon: _torchEnabled
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        onTap: _toggleTorch,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Scan ISBN Barcode',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      'Place a single barcode inside the frame.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: _isResolving ? null : _pickBarcodeImage,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text(
                      'Upload barcode image',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 220),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_isResolving)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: Colors.white,
                            ),
                          )
                        else
                          Text(
                            _message ?? 'Point the camera at a book barcode.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        if (_lastScannedCode != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Barcode: $_lastScannedCode',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _ScannerIconButton extends StatelessWidget {
  const _ScannerIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _BarcodeScannerOverlay extends StatelessWidget {
  const _BarcodeScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final overlayWidth = constraints.maxWidth * 0.74;
          final overlayHeight = overlayWidth * 0.42;
          final scanWindow = Rect.fromCenter(
            center: Offset(
              constraints.maxWidth / 2,
              constraints.maxHeight / 2,
            ),
            width: overlayWidth,
            height: overlayHeight,
          );

          return CustomPaint(
            painter: _ScannerOverlayPainter(scanWindow: scanWindow),
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: scanWindow,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 24,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({required this.scanWindow});

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.58);

    final backgroundPath = Path()..addRect(Offset.zero & size);
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(28)),
      );

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow;
  }
}
