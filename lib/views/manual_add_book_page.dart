import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../core/constants/app_colors.dart';
import '../data/models/book_detail_model.dart';
import '../data/models/google_book_search_result.dart';
import '../data/models/user_model.dart';
import '../viewmodels/manual_add_book_viewmodel.dart';

enum AddBookMode { manual, searchOnline }

class ManualAddBookPage extends StatelessWidget {
  const ManualAddBookPage({
    super.key,
    required this.user,
    this.token,
    this.initialMode = AddBookMode.manual,
    this.initialBook,
    this.initialSearchResult,
  });

  final UserModel user;
  final String? token;
  final AddBookMode initialMode;
  final BookDetailModel? initialBook;
  final GoogleBookSearchResult? initialSearchResult;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ManualAddBookViewModel(user: user, token: token),
      child: _ManualAddBookView(
        initialMode: initialMode,
        initialBook: initialBook,
        initialSearchResult: initialSearchResult,
      ),
    );
  }
}

class _ManualAddBookView extends StatefulWidget {
  const _ManualAddBookView({
    required this.initialMode,
    required this.initialBook,
    required this.initialSearchResult,
  });

  final AddBookMode initialMode;
  final BookDetailModel? initialBook;
  final GoogleBookSearchResult? initialSearchResult;

  @override
  State<_ManualAddBookView> createState() => _ManualAddBookViewState();
}

class _ManualAddBookViewState extends State<_ManualAddBookView> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _noteController = TextEditingController();
  final _startDateController = TextEditingController();
  final _finishDateController = TextEditingController();
  final _onlineSearchController = TextEditingController();

  String _selectedStatus = 'plan_to_read';
  int? _selectedRating;
  XFile? _selectedCoverImage;
  String? _selectedOnlineCoverUrl;

  static const List<_StatusOption> _statusOptions = [
    _StatusOption(value: 'plan_to_read', label: 'Plan to Read'),
    _StatusOption(value: 'reading', label: 'Reading'),
    _StatusOption(value: 'finished', label: 'Finished'),
    _StatusOption(value: 'abandoned', label: 'Abandoned'),
  ];

  @override
  void initState() {
    super.initState();
    final initialBook = widget.initialBook;
    if (initialBook != null) {
      _titleController.text = initialBook.title;
      _authorController.text = initialBook.author;
      _noteController.text = initialBook.note ?? '';
      _startDateController.text = initialBook.startDate ?? '';
      _finishDateController.text = initialBook.finishDate ?? '';
      _selectedStatus = initialBook.status;
      _selectedRating = initialBook.rating;
      _selectedOnlineCoverUrl = initialBook.coverImageUrl;
      return;
    }

    final initialSearchResult = widget.initialSearchResult;
    if (initialSearchResult != null) {
      _titleController.text = initialSearchResult.title;
      _authorController.text = initialSearchResult.authors.join(', ');
      _selectedOnlineCoverUrl = initialSearchResult.thumbnailUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _noteController.dispose();
    _startDateController.dispose();
    _finishDateController.dispose();
    _onlineSearchController.dispose();
    super.dispose();
  }

  DateTime? _tryParseIsoDate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  Future<void> _pickDate(
    TextEditingController controller, {
    DateTime? firstDate,
  }) async {
    final now = DateTime.now();
    final currentValue = _tryParseIsoDate(controller.text);
    final minimumDate = firstDate ?? DateTime(1900);
    final maximumDate = DateTime(now.year + 20);
    final initialDate = currentValue == null
        ? now
        : currentValue.isBefore(minimumDate)
        ? minimumDate
        : currentValue.isAfter(maximumDate)
        ? maximumDate
        : currentValue;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minimumDate,
      lastDate: maximumDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.darkBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    controller.text = pickedDate.toIso8601String().split('T').first;
  }

  Future<void> _pickCoverImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCoverImage = image;
      _selectedOnlineCoverUrl = null;
    });
  }

  Future<void> _openManualFromSearch(GoogleBookSearchResult book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManualAddBookPage(
          user: context.read<ManualAddBookViewModel>().user,
          token: context.read<ManualAddBookViewModel>().token,
          initialMode: AddBookMode.manual,
          initialSearchResult: book,
        ),
      ),
    );
  }

  Future<void> _submit(ManualAddBookViewModel viewModel) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final title = _titleController.text.trim();
    final author = _authorController.text.trim().isEmpty
        ? null
        : _authorController.text.trim();
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final startDate = _startDateController.text.trim().isEmpty
        ? null
        : _startDateController.text.trim();
    final finishDate = _finishDateController.text.trim().isEmpty
        ? null
        : _finishDateController.text.trim();

    final success = widget.initialBook == null
        ? await viewModel.createBook(
            title: title,
            author: author,
            status: _selectedStatus,
            rating: _selectedRating,
            note: note,
            startDate: startDate,
            finishDate: finishDate,
            coverImagePath: _selectedCoverImage?.path,
          )
        : await viewModel.updateBook(
            userBookId: widget.initialBook!.id,
            title: title,
            author: author,
            status: _selectedStatus,
            rating: _selectedRating,
            note: note,
            startDate: startDate,
            finishDate: finishDate,
            coverImagePath: _selectedCoverImage?.path,
          );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ManualAddBookViewModel>(
      builder: (context, viewModel, _) {
        final isEditing = widget.initialBook != null;
        final isSearchOnly =
            !isEditing &&
            widget.initialSearchResult == null &&
            widget.initialMode == AddBookMode.searchOnline;
        return Scaffold(
          backgroundColor: AppColors.cream,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      _TopIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      if (!isSearchOnly)
                        _TopIconButton(
                          icon: isEditing
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                          onTap: viewModel.isSubmitting
                              ? null
                              : () => _submit(viewModel),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isSearchOnly) ...[
                            const SizedBox(height: 12),
                            _OnlineSearchSection(
                              controller: _onlineSearchController,
                              viewModel: viewModel,
                              onBookSelected: _openManualFromSearch,
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            Center(
                              child: GestureDetector(
                                onTap: viewModel.isSubmitting
                                    ? null
                                    : _pickCoverImage,
                                child: Container(
                                  width: 120,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.10,
                                        ),
                                        blurRadius: 24,
                                        offset: const Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: _buildCoverPreview(viewModel),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                onPressed: viewModel.isSubmitting
                                    ? null
                                    : _pickCoverImage,
                                icon: const Icon(Icons.photo_library_rounded),
                                label: Text(
                                  _selectedCoverImage == null
                                      ? _selectedOnlineCoverUrl == null
                                            ? 'Choose cover from gallery'
                                            : 'Replace online cover'
                                      : 'Change cover',
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            const _FieldLabel('Title *'),
                            _BookTextField(
                              controller: _titleController,
                              hintText: 'Enter book title',
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Title is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Author'),
                            _BookTextField(
                              controller: _authorController,
                              hintText: 'Enter author name',
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Status'),
                            _BookDropdownField<String>(
                              initialValue: _selectedStatus,
                              items: _statusOptions
                                  .map(
                                    (option) => DropdownMenuItem<String>(
                                      value: option.value,
                                      child: Text(option.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedStatus = value;
                                });
                              },
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Rating'),
                            _RatingSelector(
                              selectedRating: _selectedRating,
                              onChanged: (value) {
                                setState(() {
                                  _selectedRating = value;
                                });
                              },
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Start Date'),
                            _BookTextField(
                              controller: _startDateController,
                              hintText: 'YYYY-MM-DD',
                              readOnly: true,
                              onTap: () => _pickDate(_startDateController),
                              suffixIcon: Icons.calendar_month_rounded,
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Finish Date'),
                            _BookTextField(
                              controller: _finishDateController,
                              hintText: 'YYYY-MM-DD',
                              readOnly: true,
                              onTap: () => _pickDate(
                                _finishDateController,
                                firstDate: _tryParseIsoDate(
                                  _startDateController.text,
                                ),
                              ),
                              suffixIcon: Icons.calendar_month_rounded,
                              validator: (value) {
                                final finishDate = _tryParseIsoDate(value);
                                final startDate = _tryParseIsoDate(
                                  _startDateController.text,
                                );

                                if (finishDate == null || startDate == null) {
                                  return null;
                                }

                                if (!finishDate.isAfter(startDate)) {
                                  return 'Finish date must be after start date';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Note'),
                            _BookTextField(
                              controller: _noteController,
                              hintText: 'Add your notes',
                              maxLines: 4,
                            ),
                          ],
                          if (viewModel.errorMessage != null) ...[
                            const SizedBox(height: 18),
                            Text(
                              viewModel.errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (!isSearchOnly) ...[
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: viewModel.isSubmitting
                                    ? null
                                    : () => _submit(viewModel),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.primary
                                      .withValues(alpha: 0.5),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                ),
                                child: viewModel.isSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isEditing
                                            ? 'Save Changes'
                                            : 'Create Book',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                          if (isSearchOnly) ...[
                            const SizedBox(height: 20),
                            Text(
                              'Tap a result to open the manual form with book information filled in.',
                              style: TextStyle(
                                color: AppColors.darkBrown.withValues(
                                  alpha: 0.72,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCover() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(
          Icons.add_photo_alternate_rounded,
          color: AppColors.primary,
          size: 38,
        ),
        SizedBox(height: 10),
        Text(
          'Add\nCover',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.darkBlue,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  Widget _buildCoverPreview(ManualAddBookViewModel viewModel) {
    if (_selectedCoverImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(_selectedCoverImage!.path), fit: BoxFit.cover),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: viewModel.isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _selectedCoverImage = null;
                        });
                      },
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                iconSize: 18,
                splashRadius: 18,
              ),
            ),
          ),
        ],
      );
    }

    if (_selectedOnlineCoverUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _selectedOnlineCoverUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildEmptyCover(),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: viewModel.isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _selectedOnlineCoverUrl = null;
                        });
                      },
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                iconSize: 18,
                splashRadius: 18,
              ),
            ),
          ),
        ],
      );
    }

    return _buildEmptyCover();
  }
}

class _OnlineSearchSection extends StatelessWidget {
  const _OnlineSearchSection({
    required this.controller,
    required this.viewModel,
    required this.onBookSelected,
  });

  final TextEditingController controller;
  final ManualAddBookViewModel viewModel;
  final ValueChanged<GoogleBookSearchResult> onBookSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Search from Google Books',
            style: TextStyle(
              color: AppColors.darkBlue,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _BookTextField(
                controller: controller,
                hintText: 'Search by title or author',
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: viewModel.isSearchingOnline
                    ? null
                    : () => viewModel.searchBooksOnline(controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: viewModel.isSearchingOnline
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded),
              ),
            ),
          ],
        ),
        if (viewModel.searchErrorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            viewModel.searchErrorMessage!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (viewModel.searchResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: viewModel.searchResults.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final book = viewModel.searchResults[index];
              return _OnlineBookCard(
                book: book,
                onTap: () => onBookSelected(book),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _OnlineBookCard extends StatelessWidget {
  const _OnlineBookCard({required this.book, required this.onTap});

  final GoogleBookSearchResult book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coverUrl = book.thumbnailUrl?.replaceFirst('http://', 'https://');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 62,
                  height: 92,
                  child: coverUrl == null
                      ? Container(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.primary,
                          ),
                        )
                      : Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: AppColors.primary.withValues(
                                  alpha: 0.10,
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.darkBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.authorText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.darkBrown.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (book.publishedDate != null &&
                        book.publishedDate!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Published: ${book.publishedDate}',
                        style: TextStyle(
                          color: AppColors.darkBrown.withValues(alpha: 0.70),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (book.isbn != null && book.isbn!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'ISBN: ${book.isbn}',
                        style: TextStyle(
                          color: AppColors.darkBrown.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Tap de dien vao form',
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.darkBlue,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BookTextField extends StatelessWidget {
  const _BookTextField({
    required this.controller,
    required this.hintText,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(
        color: AppColors.darkBlue,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppColors.darkBrown.withValues(alpha: 0.45),
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: suffixIcon == null
            ? null
            : Icon(suffixIcon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
      ),
    );
  }
}

class _BookDropdownField<T> extends StatelessWidget {
  const _BookDropdownField({
    required this.initialValue,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: initialValue,
        items: items,
        onChanged: onChanged,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(18),
        style: const TextStyle(
          color: AppColors.darkBlue,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(border: InputBorder.none),
        hint: hint == null ? null : Text(hint!),
      ),
    );
  }
}

class _RatingSelector extends StatelessWidget {
  const _RatingSelector({
    required this.selectedRating,
    required this.onChanged,
  });

  final int? selectedRating;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          ...List.generate(5, (index) {
            final starNumber = index + 1;
            final isFilled = (selectedRating ?? 0) >= starNumber;

            return Padding(
              padding: EdgeInsets.only(right: index == 4 ? 0 : 10),
              child: InkWell(
                onTap: () =>
                    onChanged(selectedRating == starNumber ? null : starNumber),
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.secondary,
                    size: 30,
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          TextButton(
            onPressed: selectedRating == null ? null : () => onChanged(null),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _StatusOption {
  const _StatusOption({required this.value, required this.label});

  final String value;
  final String label;
}
