import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

enum AddBookAction { manual, searchOnline, scanIsbn }

class AddBookMenuButton extends StatefulWidget {
  const AddBookMenuButton({
    super.key,
    required this.onSelected,
    this.menuOffset = const Offset(-162, 56),
  });

  final ValueChanged<AddBookAction> onSelected;
  final Offset menuOffset;

  @override
  State<AddBookMenuButton> createState() => _AddBookMenuButtonState();
}

class _AddBookMenuButtonState extends State<AddBookMenuButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  bool get _isMenuOpen => _overlayEntry != null;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _removeOverlay();
      return;
    }

    _showOverlay();
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeOverlay,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: widget.menuOffset,
              child: Align(
                alignment: Alignment.topLeft,
                child: _AddBookMenuCard(
                  onSelected: (action) {
                    _removeOverlay();
                    widget.onSelected(action);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
    setState(() {});
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleMenu,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              _isMenuOpen ? Icons.close_rounded : Icons.add_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddBookMenuCard extends StatelessWidget {
  const _AddBookMenuCard({required this.onSelected});

  final ValueChanged<AddBookAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AddBookMenuOption(
            icon: Icons.edit_note_rounded,
            label: 'Manual',
            onTap: () => onSelected(AddBookAction.manual),
            isFirst: true,
          ),
          _AddBookMenuOption(
            icon: Icons.travel_explore_rounded,
            label: 'Search online',
            onTap: () => onSelected(AddBookAction.searchOnline),
          ),
          _AddBookMenuOption(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan ISBN',
            onTap: () => onSelected(AddBookAction.scanIsbn),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _AddBookMenuOption extends StatelessWidget {
  const _AddBookMenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(22) : Radius.zero,
          bottom: isLast ? const Radius.circular(22) : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                  ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.darkBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
