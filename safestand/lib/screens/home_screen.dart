import 'package:flutter/material.dart';

import '../services/case_repository.dart';
import '../services/risk_scorer.dart';
import '../widgets/ai_scan_overlay.dart' show kAiAccent;
import 'remote_check_screen.dart';
import 'scan_screen.dart';

/// Entry point: loads the bundled dataset once, then offers the two input
/// paths — type the details, or scan the document.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<RiskScorer> _scorerFuture;

  @override
  void initState() {
    super.initState();
    _scorerFuture = CaseRepository().loadScorer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<RiskScorer>(
          future: _scorerFuture,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Failed to load data: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final scorer = snap.data!;

            final scheme = Theme.of(context).colorScheme;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      scheme.primary.withValues(alpha: 0.18),
                      scheme.primary.withValues(alpha: 0.0),
                    ]),
                  ),
                  child: Icon(Icons.shield_outlined,
                      size: 56, color: scheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'SafeStand',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check a land deal for known fraud warning signs — '
                  'before you pay.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 40),
                _PathCard(
                  icon: Icons.document_scanner_outlined,
                  title: 'Scan a document',
                  subtitle:
                      'Photograph the offer letter or agreement of sale — '
                      'our trained AI model checks it for fraud patterns.',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ScanScreen(scorer: scorer),
                  )),
                ),
                const SizedBox(height: 16),
                _PathCard(
                  icon: Icons.satellite_alt_outlined,
                  title: 'Check a stand',
                  subtitle:
                      'Enter the area, the seller\'s pin, or their photos — '
                      'AI verifies them against satellite imagery and '
                      'documented fraud patterns.',
                  accent: kAiAccent,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RemoteCheckScreen(scorer: scorer),
                  )),
                ),
                const SizedBox(height: 40),
                Text(
                  'Works fully offline. Documents never leave your phone.\n'
                  'A risk signal, not a legal ruling.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  const _PathCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = accent ?? scheme.primary;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.14),
                ),
                child: Icon(icon, size: 26, color: tint),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
