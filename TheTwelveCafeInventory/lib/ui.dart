import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CafeColors {
  static const espresso = Color(0xFF4A3528);
  static const espressoDeep = Color(0xFF241A15);
  static const caramel = Color(0xFFB88A5A);
  static const latte = Color(0xFFE7D8C6);
  static const cream = Color(0xFFF5F4F1);
  static const creamDeep = Color(0xFFEDE9E2);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF221F1D);
  static const muted = Color(0xFF746E69);
  static const success = Color(0xFF6F874E);
  static const warning = Color(0xFFB98244);
  static const danger = Color(0xFFB6504B);
  static const neutral = Color(0xFF73706D);
  static const line = Color(0xFFE4E1DC);
}

ThemeData buildCafeTheme({required Brightness brightness}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: dark ? const Color(0xFFD7A677) : CafeColors.espresso,
    brightness: brightness,
  );

  final bg = dark ? const Color(0xFF161311) : CafeColors.cream;
  final surface = dark ? const Color(0xFF211D1A) : CafeColors.paper;
  final outline = dark ? const Color(0xFF4A433E) : CafeColors.line;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme.copyWith(
      primary: dark ? const Color(0xFFD7A677) : CafeColors.espresso,
      secondary: dark ? const Color(0xFFBFA58D) : CafeColors.caramel,
      surface: surface,
      error: dark ? const Color(0xFFF08C86) : CafeColors.danger,
      outline: outline,
    ),
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: dark ? Colors.white : CafeColors.ink,
      titleTextStyle: TextStyle(
        color: dark ? Colors.white : CafeColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: .2,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF2A2522) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide(color: outline),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: surface,
      indicatorColor: dark ? const Color(0xFF513D32) : CafeColors.latte,
      height: 74,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 12);
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          trailing!,
        ],
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: padding, child: child));
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer, size: 30),
              ),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.45)),
              if (action != null) ...[
                const SizedBox(height: 18),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(tint.withAlpha(30), scheme.surface),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: tint, size: 20),
                  ),
                  const Spacer(),
                  if (onTap != null) Icon(Icons.arrow_outward_rounded, size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 18),
              Text('$value', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.8)),
              const SizedBox(height: 3),
              Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

String prettyDateTime(dynamic value) {
  if (value == null) return 'Not recorded';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('MMM d, yyyy • h:mm a').format(parsed.toLocal());
}

String titleCaseCode(String value) {
  return value
      .split('_')
      .map((part) => part.isEmpty ? part : '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');
}

enum StatusTone { success, warning, danger, neutral }

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone});
  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (tone) {
      StatusTone.success => CafeColors.success,
      StatusTone.warning => CafeColors.warning,
      StatusTone.danger => CafeColors.danger,
      StatusTone.neutral => dark ? const Color(0xFFBDB3AC) : CafeColors.neutral,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withAlpha(dark ? 42 : 24), borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: .15)),
    );
  }
}
