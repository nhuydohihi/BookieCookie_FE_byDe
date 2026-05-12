import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_colors.dart';
import '../core/services/api_service.dart';
import '../data/models/user_model.dart';

class QuoteScanPage extends StatefulWidget {
  const QuoteScanPage({
    super.key,
    required this.user,
    required this.userBookId,
    required this.bookTitle,
    this.token,
  });

  final UserModel user;
  final int userBookId;
  final String bookTitle;
  final String? token;

  @override
  State<QuoteScanPage> createState() => _QuoteScanPageState();
}

class _QuoteScanPageState extends State<QuoteScanPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final ApiService _apiService = ApiService();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _pageController = TextEditingController();

  XFile? _selectedImage;
  bool _isRecognizing = false;
  bool _isSaving = false;
  double? _ocrConfidence;
  String? _errorMessage;

  @override
  void dispose() {
    _contentController.dispose();
    _noteController.dispose();
    _pageController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickAndRecognizeImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (pickedFile == null) {
        return;
      }

      setState(() {
        _selectedImage = pickedFile;
        _isRecognizing = true;
        _errorMessage = null;
        _ocrConfidence = null;
      });

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final normalizedText = recognizedText.blocks
          .map((block) => block.text.trim())
          .where((text) => text.isNotEmpty)
          .join('\n');
      final averageConfidence = _estimateAverageConfidence(recognizedText);

      if (!mounted) {
        return;
      }

      setState(() {
        _contentController.text = normalizedText;
        _ocrConfidence = averageConfidence;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Không thể nhận diện chữ từ ảnh đã chọn.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizing = false;
        });
      }
    }
  }

  double? _estimateAverageConfidence(RecognizedText recognizedText) {
    var confidenceTotal = 0.0;
    var confidenceCount = 0;

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final confidence = element.confidence;
          if (confidence != null) {
            confidenceTotal += confidence;
            confidenceCount += 1;
          }
        }
      }
    }

    if (confidenceCount == 0) {
      return null;
    }

    return (confidenceTotal / confidenceCount).clamp(0, 1) * 100;
  }

  Future<void> _saveQuote() async {
    if (_selectedImage == null) {
      setState(() {
        _errorMessage = 'Hãy chọn ảnh quote trước khi lưu.';
      });
      return;
    }

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() {
        _errorMessage = 'OCR chưa có nội dung. Hãy chỉnh lại text trước khi lưu.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.postMultipart(
        '/quotes',
        fields: {
          'user_id': widget.user.id.toString(),
          'user_book_id': widget.userBookId.toString(),
          'content': content,
          'ocr_text': content,
          'ocr_status': 'processed',
          'ocr_confidence': _ocrConfidence?.toStringAsFixed(2) ?? '',
          'page_number': _pageController.text.trim(),
          'note': _noteController.text.trim(),
        },
        fileField: 'image',
        filePath: _selectedImage!.path,
        headers: widget.token == null
            ? null
            : {'Authorization': 'Bearer ${widget.token}'},
      );

      if (!mounted) {
        return;
      }

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote đã được lưu.')),
        );
        Navigator.pop(context, true);
        return;
      }

      setState(() {
        _errorMessage =
            result['message'] as String? ?? 'Không thể lưu quote lúc này.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ActionButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    'Scan Quote',
                    style: TextStyle(
                      color: AppColors.darkBlue.withValues(alpha: 0.92),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 50),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                widget.bookTitle,
                style: const TextStyle(
                  color: AppColors.darkBlue,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Chọn ảnh quote, để Google ML Kit nhận diện chữ, rồi chỉnh lại trước khi lưu.',
                style: TextStyle(
                  color: AppColors.darkBrown.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              _CardSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isRecognizing || _isSaving
                            ? null
                            : _pickAndRecognizeImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: Text(
                          _selectedImage == null
                              ? 'Chọn ảnh quote'
                              : 'Chọn ảnh khác',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.file(
                          File(_selectedImage!.path),
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image_search_rounded,
                            size: 44,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    if (_isRecognizing) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Google ML Kit đang nhận diện chữ trong ảnh...',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_ocrConfidence != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        'OCR confidence: ${_ocrConfidence!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _CardSection(
                title: 'Nội dung quote',
                child: TextField(
                  controller: _contentController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Text OCR sẽ xuất hiện ở đây để bạn chỉnh lại...',
                    border: InputBorder.none,
                  ),
                  style: TextStyle(
                    color: AppColors.darkBrown.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _CardSection(
                title: 'Thông tin thêm',
                child: Column(
                  children: [
                    TextField(
                      controller: _pageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Trang số mấy?',
                        border: InputBorder.none,
                      ),
                    ),
                    Container(
                      height: 1,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    TextField(
                      controller: _noteController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Ghi chú của bạn về quote này...',
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving || _isRecognizing ? null : _saveQuote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    _isSaving ? 'Đang lưu...' : 'Lưu quote',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.darkBlue),
        ),
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: AppColors.darkBlue,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
