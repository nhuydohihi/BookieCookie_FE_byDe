import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

enum AppTab {
  home('Home', Icons.home_rounded),
  library('Library', Icons.local_library_outlined),
  challenge('Challenge', Icons.flag_outlined),
  statistic('Statistic', Icons.bar_chart_rounded),
  account('Account', Icons.person_outline_rounded);

  const AppTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.currentTab,
    this.onTabSelected,
  });

  final AppTab currentTab;
  final ValueChanged<AppTab>? onTabSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: AppTab.values.map((tab) {
            final isSelected = tab == currentTab;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onTabSelected == null ? null : () => onTabSelected!(tab),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tab.icon,
                            color: isSelected ? AppColors.primary : AppColors.darkBrown,
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tab.label,
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.darkBrown,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
