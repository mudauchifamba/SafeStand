import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_service.dart';
import '../services/risk_scorer.dart';
import 'result_screen.dart';

/// Document scan path: photograph (or pick) an offer letter / agreement of
/// sale. On-device OCR extracts the text, which is then run through the
/// red-flag rules. Nothing leaves the phone.
class ScanScreen extends StatefulWidget {
  final RiskScorer scorer;

  const ScanScreen({super.key, required this.scorer});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _ocr = OcrService();
  final _areaController = TextEditingController();

  File? _image;
  String? _extractedText;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ocr.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 2400);
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
      final text = await _ocr.extractText(picked.path);
      setState(() {
        _image = File(picked.path);
        _extractedText = text;
        _busy = false;
      });
      if (text.trim().isEmpty) {
        setState(() => _error =
            'No text could be read from that image. Try better lighting and hold the camera flat over the document.');
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Could not read the document: $e';
      });
    }
  }

  void _check() {
    final text = _extractedText ?? '';
    if (text.trim().isEmpty) return;

    final verdict = widget.scorer.score(
      area: _areaController.text,
      documentText: text,
    );

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(
        verdict: verdict,
        area: _areaController.text.trim(),
        scannedText: text,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasText = (_extractedText ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan a document')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Photograph the offer letter or agreement of sale. The text is '
              'read on your phone — the document is never uploaded anywhere.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('Reading document…')),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_image != null) ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_image!, height: 220, fit: BoxFit.cover),
              ),
            ],
            if (hasText) ...[
              const SizedBox(height: 20),
              Text('Extracted text',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _extractedText!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: 'Area / suburb (optional, improves the check)',
                  hintText: 'e.g. Budiriro, Harare',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _check,
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Check this document'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
