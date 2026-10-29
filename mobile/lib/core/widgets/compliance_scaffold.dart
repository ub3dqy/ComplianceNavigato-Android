import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../theme/design_tokens.dart';

/// Native green-v1 page frame. Only the content scrolls; the header remains
/// readable at large text sizes rather than clipping inside a fixed AppBar.
final class ComplianceScaffold extends ConsumerWidget {
  const ComplianceScaffold({
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.footer,
    this.showOrganization = true,
    super.key,
  });

  final Widget body;
  final AppBar? appBar;
  final Widget? floatingActionButton;
  final Widget? footer;
  final bool showOrganization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final organization = showOrganization
        ? ref.watch(currentOrganizationProvider)
        : null;
    final router = GoRouter.maybeOf(context);
    final canPop = router?.canPop() ?? false;
    final fab = floatingActionButton;
    final header = appBar;
    final canReturnHome =
        organization != null &&
        router != null &&
        router.state.uri.path != '/dashboard';
    final refresh = header?.actions
        ?.whereType<IconButton>()
        .where((button) => button.tooltip == 'Обновить')
        .firstOrNull;
    Widget content = body;
    if (fab is FloatingActionButton && refresh?.onPressed != null) {
      content = ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          physics: const AlwaysScrollableScrollPhysics(),
        ),
        child: body is RefreshIndicator
            ? body
            : RefreshIndicator(
                onRefresh: () async => refresh!.onPressed!(),
                child: body,
              ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (header != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          if (header.leading != null)
                            header.leading!
                          else if (canPop || canReturnHome)
                            IconButton(
                              tooltip: 'Назад',
                              onPressed: () => canPop
                                  ? router!.pop()
                                  : router!.go('/dashboard'),
                              icon: const Icon(Icons.arrow_back),
                            ),
                          Expanded(
                            child: DefaultTextStyle(
                              style: theme.textTheme.titleLarge!.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                              child: header.title ?? const SizedBox.shrink(),
                            ),
                          ),
                          if (fab is FloatingActionButton) ...<Widget>[
                            IconButton(
                              tooltip: fab.tooltip ?? 'Добавить',
                              onPressed: fab.onPressed,
                              icon: const Icon(Icons.add),
                            ),
                            ...?header.actions?.where(
                              (action) =>
                                  action is! IconButton ||
                                  action.tooltip != 'Обновить',
                            ),
                          ] else
                            ...?header.actions,
                        ],
                      ),
                      if (organization != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: router == null
                                ? null
                                : () => router.go('/organizations'),
                            icon: const Icon(Icons.business_outlined, size: 15),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Flexible(child: Text(organization.shortName)),
                                const SizedBox(width: 6),
                                const Icon(Icons.expand_more, size: 15),
                              ],
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  theme.colorScheme.onSurfaceVariant,
                              textStyle: theme.textTheme.bodySmall,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                          ),
                        ),
                      if (header.bottom != null) header.bottom!,
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: SizedBox.expand(child: content),
                ),
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

final class ComplianceIconTile extends StatelessWidget {
  const ComplianceIconTile(this.icon, {super.key, this.size = 42});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadii.input),
    ),
    child: Icon(
      icon,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
      size: 22,
    ),
  );
}

/// A list row opens its details without changing the selected main section.
final class ComplianceDetailCard extends StatelessWidget {
  const ComplianceDetailCard({
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
    this.trailing,
    this.childrenPadding,
    super.key,
  });
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsetsGeometry? childrenPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 18),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: title,
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
            actions: <Widget>[
              if (trailing is IconButton)
                IconButton(
                  tooltip: (trailing as IconButton).tooltip,
                  icon: (trailing as IconButton).icon,
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    (trailing as IconButton).onPressed?.call();
                  },
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class ComplianceNotice extends StatelessWidget {
  const ComplianceNotice(this.text, {super.key, this.review = true});
  final String text;
  final bool review;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.complianceColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: review
            ? semantic.needsHumanReviewContainer
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            review ? Icons.fact_check_outlined : Icons.info_outline,
            size: 18,
            color: review
                ? semantic.needsHumanReview
                : theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: review
                    ? semantic.needsHumanReview
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
