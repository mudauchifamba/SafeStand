import 'package:flutter/material.dart';

import '../services/risk_scorer.dart';
import 'result_screen.dart';

/// Manual entry path: the user types the stand details they were given by the
/// seller. No document needed — the area/seller are checked against the
/// documented seed dataset.
class ManualEntryScreen extends StatefulWidget {
  final RiskScorer scorer;

  const ManualEntryScreen({super.key, required this.scorer});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _standController = TextEditingController();
  final _areaController = TextEditingController();
  final _sellerController = TextEditingController();

  @override
  void dispose() {
    _standController.dispose();
    _areaController.dispose();
    _sellerController.dispose();
    super.dispose();
  }

  void _check() {
    if (!_formKey.currentState!.validate()) return;

    final verdict = widget.scorer.score(
      area: _areaController.text,
      seller: _sellerController.text,
    );

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(
        verdict: verdict,
        standNumber: _standController.text.trim(),
        area: _areaController.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter stand details')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Type the details exactly as the seller gave them to you.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _standController,
                decoration: const InputDecoration(
                  labelText: 'Stand number (optional)',
                  hintText: 'e.g. Stand 1234',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: 'Area / suburb',
                  hintText: 'e.g. Budiriro, Harare',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty &&
                      _sellerController.text.trim().isEmpty) {
                    return 'Enter at least the area or the seller name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sellerController,
                decoration: const InputDecoration(
                  labelText: 'Seller / cooperative name',
                  hintText: 'e.g. XYZ Housing Cooperative',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _check,
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Check risk'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
