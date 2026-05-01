part of '../saca_controls.dart';

class SacaErrorBanner extends StatelessWidget {
  const SacaErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE7E4),
        borderRadius: BorderRadius.circular(SacaTheme.radius),
        border: Border.all(color: const Color(0xFFE9A09A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: SacaTheme.small.copyWith(color: SacaTheme.emergency),
        ),
      ),
    );
  }
}
