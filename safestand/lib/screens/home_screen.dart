import 'package:flutter/material.dart';

import '../services/case_repository.dart';
import '../services/risk_scorer.dart';
import 'manual_entry_screen.dart';
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

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                Icon(Icons.shield_outlined,
                    size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  'SafeStand',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
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
                  icon: Icons.edit_note,
                  title: 'Enter stand details',
                  subtitle:
                      'Type the stand number, area and seller you were given.',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ManualEntryScreen(scorer: scorer),
                  )),
                ),
                const SizedBox(height: 16),
                _PathCard(
                  icon: Icons.document_scanner_outlined,
                  title: 'Scan a document',
                  subtitle:
                      'Photograph the offer letter or agreement of sale.',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ScanScreen(scorer: scorer),
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

  const _PathCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
