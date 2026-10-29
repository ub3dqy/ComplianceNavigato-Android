import 'package:flutter/material.dart';

/// Owner-approved Android design: variant 2, «Свежий зелёный», green-v1.
///
/// Values in this file are intentionally explicit and covered by immutable
/// tests. Feature widgets must consume the theme instead of defining colors.
abstract final class AppColorTokens {
  static const Color lightPrimary = Color(0xFF078B4B);
  static const Color lightPrimaryDark = Color(0xFF056A39);
  static const Color lightPrimaryAccent = Color(0xFF38C978);
  static const Color lightPrimaryContainer = Color(0xFFEAF8F0);
  static const Color lightBackground = Color(0xFFF4F8F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEEF5F0);
  static const Color lightTextPrimary = Color(0xFF15251B);
  static const Color lightTextSecondary = Color(0xFF607067);
  static const Color lightOutline = Color(0xFFDCE8E0);
  static const Color lightDisabled = Color(0xFF95A29A);

  static const Color darkBackground = Color(0xFF09150F);
  static const Color darkSurface = Color(0xFF122219);
  static const Color darkSurfaceVariant = Color(0xFF182C21);
  static const Color darkPrimary = Color(0xFF35D07F);
  static const Color darkPrimaryContainer = Color(0xFF174D31);
  static const Color darkTextPrimary = Color(0xFFF1F8F4);
  static const Color darkTextSecondary = Color(0xFFA9B9AF);
  static const Color darkOutline = Color(0xFF294236);

  static const Color lightSuccess = Color(0xFF1C7450);
  static const Color lightSuccessContainer = Color(0xFFDDF4E9);
  static const Color lightWarning = Color(0xFF9A5A00);
  static const Color lightWarningContainer = Color(0xFFFFE8C3);
  static const Color lightError = Color(0xFFBA1A1A);
  static const Color lightErrorContainer = Color(0xFFFFDAD6);
  static const Color lightInformation = Color(0xFF245FAF);
  static const Color lightInformationContainer = Color(0xFFD8E6FF);
  static const Color lightNeedsReview = Color(0xFF7046A2);
  static const Color lightNeedsReviewContainer = Color(0xFFEEDBFF);

  static const Color darkSuccess = Color(0xFF70D7A6);
  static const Color darkSuccessContainer = Color(0xFF174B35);
  static const Color darkWarning = Color(0xFFFFB95A);
  static const Color darkWarningContainer = Color(0xFF573700);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color darkInformation = Color(0xFFA9C7FF);
  static const Color darkInformationContainer = Color(0xFF16477F);
  static const Color darkNeedsReview = Color(0xFFDAB9FF);
  static const Color darkNeedsReviewContainer = Color(0xFF4E2B75);
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadii {
  static const double input = 12;
  static const double button = 13;
  static const double card = 16;
  static const double hero = 24;
  static const double pill = 999;
}

abstract final class AppDimensions {
  static const double minimumTouchTarget = 48;
  static const double contentMaxWidth = 1120;
}

@immutable
final class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.information,
    required this.onInformation,
    required this.informationContainer,
    required this.onInformationContainer,
    required this.needsHumanReview,
    required this.onNeedsHumanReview,
    required this.needsHumanReviewContainer,
    required this.onNeedsHumanReviewContainer,
    required this.background,
    required this.disabled,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color information;
  final Color onInformation;
  final Color informationContainer;
  final Color onInformationContainer;
  final Color needsHumanReview;
  final Color onNeedsHumanReview;
  final Color needsHumanReviewContainer;
  final Color onNeedsHumanReviewContainer;
  final Color background;
  final Color disabled;

  static const AppSemanticColors light = AppSemanticColors(
    success: AppColorTokens.lightSuccess,
    onSuccess: Colors.white,
    successContainer: AppColorTokens.lightSuccessContainer,
    onSuccessContainer: Color(0xFF0D3A28),
    warning: AppColorTokens.lightWarning,
    onWarning: Colors.white,
    warningContainer: AppColorTokens.lightWarningContainer,
    onWarningContainer: Color(0xFF3A2500),
    information: AppColorTokens.lightInformation,
    onInformation: Colors.white,
    informationContainer: AppColorTokens.lightInformationContainer,
    onInformationContainer: Color(0xFF0B315F),
    needsHumanReview: AppColorTokens.lightNeedsReview,
    onNeedsHumanReview: Colors.white,
    needsHumanReviewContainer: AppColorTokens.lightNeedsReviewContainer,
    onNeedsHumanReviewContainer: Color(0xFF351252),
    background: AppColorTokens.lightBackground,
    disabled: AppColorTokens.lightDisabled,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: AppColorTokens.darkSuccess,
    onSuccess: Color(0xFF063923),
    successContainer: AppColorTokens.darkSuccessContainer,
    onSuccessContainer: Color(0xFFB8F2D3),
    warning: AppColorTokens.darkWarning,
    onWarning: Color(0xFF482900),
    warningContainer: AppColorTokens.darkWarningContainer,
    onWarningContainer: Color(0xFFFFDDAF),
    information: AppColorTokens.darkInformation,
    onInformation: Color(0xFF06305F),
    informationContainer: AppColorTokens.darkInformationContainer,
    onInformationContainer: Color(0xFFD8E6FF),
    needsHumanReview: AppColorTokens.darkNeedsReview,
    onNeedsHumanReview: Color(0xFF3E1761),
    needsHumanReviewContainer: AppColorTokens.darkNeedsReviewContainer,
    onNeedsHumanReviewContainer: Color(0xFFF0DBFF),
    background: AppColorTokens.darkBackground,
    disabled: Color(0xFF6E7D74),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? information,
    Color? onInformation,
    Color? informationContainer,
    Color? onInformationContainer,
    Color? needsHumanReview,
    Color? onNeedsHumanReview,
    Color? needsHumanReviewContainer,
    Color? onNeedsHumanReviewContainer,
    Color? background,
    Color? disabled,
  }) => AppSemanticColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    information: information ?? this.information,
    onInformation: onInformation ?? this.onInformation,
    informationContainer: informationContainer ?? this.informationContainer,
    onInformationContainer:
        onInformationContainer ?? this.onInformationContainer,
    needsHumanReview: needsHumanReview ?? this.needsHumanReview,
    onNeedsHumanReview: onNeedsHumanReview ?? this.onNeedsHumanReview,
    needsHumanReviewContainer:
        needsHumanReviewContainer ?? this.needsHumanReviewContainer,
    onNeedsHumanReviewContainer:
        onNeedsHumanReviewContainer ?? this.onNeedsHumanReviewContainer,
    background: background ?? this.background,
    disabled: disabled ?? this.disabled,
  );

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      information: Color.lerp(information, other.information, t)!,
      onInformation: Color.lerp(onInformation, other.onInformation, t)!,
      informationContainer: Color.lerp(
        informationContainer,
        other.informationContainer,
        t,
      )!,
      onInformationContainer: Color.lerp(
        onInformationContainer,
        other.onInformationContainer,
        t,
      )!,
      needsHumanReview: Color.lerp(
        needsHumanReview,
        other.needsHumanReview,
        t,
      )!,
      onNeedsHumanReview: Color.lerp(
        onNeedsHumanReview,
        other.onNeedsHumanReview,
        t,
      )!,
      needsHumanReviewContainer: Color.lerp(
        needsHumanReviewContainer,
        other.needsHumanReviewContainer,
        t,
      )!,
      onNeedsHumanReviewContainer: Color.lerp(
        onNeedsHumanReviewContainer,
        other.onNeedsHumanReviewContainer,
        t,
      )!,
      background: Color.lerp(background, other.background, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}

extension ComplianceThemeData on ThemeData {
  AppSemanticColors get complianceColors =>
      extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
