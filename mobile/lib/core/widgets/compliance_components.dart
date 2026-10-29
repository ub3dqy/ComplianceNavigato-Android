import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

enum SemanticStatus {
  success,
  warning,
  error,
  information,
  needsHumanReview,
  neutral,
}

final class GreenHeroHeader extends StatelessWidget {
  const GreenHeroHeader({
    required this.organizationName,
    required this.progress,
    this.onRefresh,
    super.key,
  });

  final String organizationName;
  final int progress;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final int safeProgress = progress.clamp(0, 100);
    final Color start = dark
        ? AppColorTokens.darkPrimaryContainer
        : AppColorTokens.lightPrimaryDark;
    final Color end = dark ? const Color(0xFF0E6B3B) : const Color(0xFF067C44);
    return Semantics(
      container: true,
      header: true,
      label:
          'Комплаенс-Навигатор Pilot. Организация $organizationName. Общий прогресс $safeProgress процентов.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[start, end],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadii.hero),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _ShieldCheckMark(),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Комплаенс-Навигатор Pilot',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          organizationName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Добро пожаловать. Начните с самого важного действия.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (onRefresh != null)
                    IconButton(
                      onPressed: onRefresh,
                      color: Colors.white,
                      tooltip: 'Обновить данные',
                      icon: const Icon(Icons.refresh),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ComplianceProgress(
                value: safeProgress / 100,
                label: 'Общий прогресс',
                valueLabel: '$safeProgress%',
                foregroundColor: Colors.white,
                trackColor: Colors.white.withValues(alpha: 0.24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ShieldCheckMark extends StatelessWidget {
  const _ShieldCheckMark();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Защищённая проверка',
    child: Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: const Icon(
        Icons.verified_user_outlined,
        color: Colors.white,
        size: 34,
      ),
    ),
  );
}

final class ComplianceCard extends StatelessWidget {
  const ComplianceCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget content = Padding(padding: padding, child: child);
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: colors.surface,
        elevation: 0.5,
        shadowColor: colors.shadow.withValues(alpha: 0.09),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                canRequestFocus: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppDimensions.minimumTouchTarget,
                  ),
                  child: content,
                ),
              ),
      ),
    );
  }
}

final class ComplianceActionCard extends StatelessWidget {
  const ComplianceActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.status,
    this.loading = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ComplianceCard(
      onTap: loading ? null : onTap,
      semanticLabel: '$title. $subtitle',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.input),
            ),
            child: Icon(icon, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                if (status != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  status!,
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (loading)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

final class ComplianceMetricCard extends StatelessWidget {
  const ComplianceMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.status = SemanticStatus.neutral,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final SemanticStatus status;

  @override
  Widget build(BuildContext context) {
    final _StatusColors statusColors = _statusColors(context, status);
    return ComplianceCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      semanticLabel: '$label: $value',
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColors.background,
              borderRadius: BorderRadius.circular(AppRadii.input),
            ),
            child: Icon(icon, color: statusColors.foreground, size: 22),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class ComplianceProgress extends StatelessWidget {
  const ComplianceProgress({
    required this.value,
    required this.label,
    required this.valueLabel,
    this.foregroundColor,
    this.trackColor,
    super.key,
  });

  final double value;
  final String label;
  final String valueLabel;
  final Color? foregroundColor;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double safeValue = value.clamp(0, 1);
    final Color foreground =
        foregroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? colors.primary
            : AppColorTokens.lightPrimaryDark);
    final Color labelColor = foregroundColor ?? colors.onSurfaceVariant;
    return Semantics(
      label: '$label $valueLabel',
      value: valueLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: labelColor, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: safeValue,
              minHeight: 6,
              color: foreground,
              backgroundColor: trackColor ?? colors.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

final class SemanticStatusBadge extends StatelessWidget {
  const SemanticStatusBadge({
    required this.label,
    required this.status,
    super.key,
  });

  final String label;
  final SemanticStatus status;

  @override
  Widget build(BuildContext context) {
    final _StatusColors colors = _statusColors(context, status);
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: colors.foreground.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(colors.icon, size: 16, color: colors.foreground),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class GreenPrimaryButton extends StatelessWidget {
  const GreenPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: loading ? null : onPressed,
    icon: loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon ?? Icons.arrow_forward),
    label: Text(label),
  );
}

final class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _StatePanel(
    icon: icon,
    title: title,
    message: message,
    status: SemanticStatus.neutral,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

final class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    required this.onRetry,
    this.title = 'Не удалось загрузить данные',
    this.retryLabel = 'Повторить',
    this.icon = Icons.error_outline,
    super.key,
  });

  final String title;
  final String message;
  final String retryLabel;
  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _StatePanel(
    icon: icon,
    title: title,
    message: message,
    status: SemanticStatus.error,
    actionLabel: retryLabel,
    onAction: onRetry,
  );
}

final class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.status,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final SemanticStatus status;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(context, status);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: status == SemanticStatus.neutral
                      ? theme.colorScheme.primaryContainer
                      : colors.background,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: status == SemanticStatus.neutral
                      ? theme.colorScheme.onPrimaryContainer
                      : colors.foreground,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 12),
                GreenPrimaryButton(
                  label: actionLabel!,
                  icon: Icons.refresh,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    this.itemCount = 6,
    this.includeHero = true,
    super.key,
  });

  final int itemCount;
  final bool includeHero;

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      liveRegion: true,
      label: 'Загрузка данных',
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, int index) => ExcludeSemantics(
          child: Container(
            height: includeHero && index == 0 ? 168 : 80,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
final class ComplianceNavigationDestination {
  const ComplianceNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

final class AdaptiveNavigation extends StatelessWidget {
  const AdaptiveNavigation({
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.child,
    super.key,
  });

  final int selectedIndex;
  final List<ComplianceNavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool wide = constraints.maxWidth >= 800;
      if (wide) {
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: <Widget>[
                NavigationRail(
                  minWidth: 100,
                  groupAlignment: -1,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map(
                        (ComplianceNavigationDestination item) =>
                            NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(item.selectedIcon),
                              label: Text(item.label),
                            ),
                      )
                      .toList(growable: false),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        body: SafeArea(child: child),
        bottomNavigationBar: NavigationBar(
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations
              .map(
                (ComplianceNavigationDestination item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                  tooltip: item.label,
                ),
              )
              .toList(growable: false),
        ),
      );
    },
  );
}

final class _StatusColors {
  const _StatusColors(this.background, this.foreground, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;
}

_StatusColors _statusColors(BuildContext context, SemanticStatus status) {
  final ThemeData theme = Theme.of(context);
  final AppSemanticColors semantic = theme.complianceColors;
  return switch (status) {
    SemanticStatus.success => _StatusColors(
      semantic.successContainer,
      semantic.success,
      Icons.check_circle_outline,
    ),
    SemanticStatus.warning => _StatusColors(
      semantic.warningContainer,
      semantic.warning,
      Icons.warning_amber_rounded,
    ),
    SemanticStatus.error => _StatusColors(
      theme.colorScheme.errorContainer,
      theme.colorScheme.onErrorContainer,
      Icons.error_outline,
    ),
    SemanticStatus.information => _StatusColors(
      semantic.informationContainer,
      semantic.information,
      Icons.info_outline,
    ),
    SemanticStatus.needsHumanReview => _StatusColors(
      semantic.needsHumanReviewContainer,
      semantic.needsHumanReview,
      Icons.fact_check_outlined,
    ),
    SemanticStatus.neutral => _StatusColors(
      theme.colorScheme.surfaceContainerHighest,
      theme.colorScheme.onSurfaceVariant,
      Icons.circle_outlined,
    ),
  };
}
