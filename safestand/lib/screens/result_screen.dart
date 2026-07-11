import 'package:flutter/material.dart';

import '../models/models.dart';

/// Shows the Green / Amber / Red verdict with every reason that contributed,
/// plus the recommended next steps. The reasons ARE the product — a score
/// without an explanation would be useless (and irresponsible) here.
class ResultScreen extends StatelessWidget {
  final RiskVerdict verdict;
  final String? standNumber;
  final String? area;
  final String? scannedText;

  const ResultScreen({
    super.key,
    required this.verdict,
    this.standNumber,
    this.area,
    this.scannedText,
  });

  Color _bandColor(BuildContext context) {
    switch (verdict.band) {
      case RiskBand.green:
        return const Color(0xFF2E7D32);
      case RiskBand.amber:
        return const Color(0xFFEF6C00);
      case RiskBand.red:
        return const Color(0xFFC62828);
    }
  }

  IconData get _bandIcon {
    switch (verdict.band) {
      case RiskBand.green:
        return Icons.check_circle_outline;
      case RiskBand.amber:
        return Icons.warning_amber_outlined;
      case RiskBand.red:
        return Icons.report_outlined;
    }
  }

  String get _bandMessage {
    switch (verdict.band) {
      case RiskBand.green:
        return 'No known warning signs found. This is NOT proof the deal is '
            'legal — always verify independently before paying.';
      case RiskBand.amber:
        return 'Some warning signs found. Do not pay anything until you have '
            'verified this deal with the authorities below.';
      case RiskBand.red:
        return 'Strong warning signs found. This deal matches known fraud '
            'patterns. Do NOT pay. Verify with the authorities below first.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _bandColor(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Risk check result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // --- Verdict banner ---------------------------------------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(_bandIcon, size: 56, color: color),
                  const SizedBox(height: 8),
                  Text(
                    verdict.band.label.toUpperCase(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text('Risk score: ${verdict.score} / 100',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(_bandMessage, textAlign: TextAlign.center),
                ],
              ),
            ),

            if ((standNumber ?? '').isNotEmpty || (area ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                [
                  if ((standNumber ?? '').isNotEmpty) 'Stand: $standNumber',
                  if ((area ?? '').isNotEmpty) 'Area: $area',
                ].join('   •   '),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],

            // --- Reasons ----------------------------------------------
            const SizedBox(height: 24),
            Text('Why', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...verdict.reasons.map((r) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      r.weight > 0
                          ? Icons.flag_outlined
                          : Icons.info_outline,
                      color: r.weight >= 3
                          ? const Color(0xFFC62828)
                          : r.weight > 0
                              ? const Color(0xFFEF6C00)
                              : null,
                    ),
                    title: Text(r.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(r.explanation),
                  ),
                )),

            // --- Next steps -------------------------------------------
            const SizedBox(height: 24),
            Text('What to do next',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...verdict.nextSteps.asMap().entries.map((e) => ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${e.key + 1}',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  title: Text(e.value),
                  dense: true,
                )),

            // --- Disclaimer -------------------------------------------
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'SafeStand gives a risk signal, not a legal ruling. It cannot '
                'confirm a stand is legally clean. Always verify with the Deeds '
                'Registry, the Surveyor-General, and your local council before '
                'paying any money.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Check another deal'),
            ),
          ],
        ),
      ),
    );
  }
}
