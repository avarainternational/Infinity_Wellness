import 'package:flutter/material.dart';
import 'package:employee_wellness/app/constant/resources/app_colors.dart';
import 'package:employee_wellness/app/constant/resources/app_dimens.dart';
import 'package:employee_wellness/app/constant/resources/app_images.dart';

class FeatureHeader extends StatelessWidget {
  const FeatureHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    child: Image.asset(
                      AppImages.logo,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'INFINITY WELLNESS',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primaryDarkBlue,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 5),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        FractionallySizedBox(
          widthFactor: .32,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  AppColors.primary,
                  AppColors.primaryDarkBlue,
                  AppColors.primaryDeep,
                ],
                stops: <double>[0, .76, .76],
              ),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ],
    );
  }
}

class WalletPage extends StatelessWidget {
  const WalletPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screenPadding,
            18,
            AppDimens.screenPadding,
            32,
          ),
          children: <Widget>[
            FeatureHeader(title: title, subtitle: subtitle, trailing: trailing),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class WalletCard extends StatelessWidget {
  const WalletCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class WalletStatusBadge extends StatelessWidget {
  const WalletStatusBadge({
    super.key,
    required this.label,
    this.pending = false,
  });

  final String label;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pending ? AppColors.primarySoft : AppColors.violetSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: TextStyle(
            color: pending ? AppColors.primaryDark : AppColors.violet,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
