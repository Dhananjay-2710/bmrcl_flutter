import 'dart:io';
import 'package:flutter/material.dart';

class CheckPreviewResult {
  final bool confirm;
  final bool forceIfFar;
  CheckPreviewResult({required this.confirm, required this.forceIfFar});
}

class CheckPreviewSheet extends StatefulWidget {
  final File imageFile;
  final String title; // "Check-In" or "Check-Out"
  final String stationName;
  final double distanceMeters;
  final double allowedRadiusMeters;

  const CheckPreviewSheet({
    super.key,
    required this.imageFile,
    required this.title,
    required this.stationName,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
  });

  @override
  State<CheckPreviewSheet> createState() => _CheckPreviewSheetState();
}

class _CheckPreviewSheetState extends State<CheckPreviewSheet> {
  bool force = false;

  @override
  Widget build(BuildContext context) {
    final isFar = widget.distanceMeters > widget.allowedRadiusMeters;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(widget.imageFile, height: 220, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            Text(
              'Station: ${widget.stationName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Distance: ${widget.distanceMeters.toStringAsFixed(1)} m'),
            if (isFar) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Text(
                  'You are outside the allowed radius. You can force proceed if authorized.',
                  textAlign: TextAlign.center,
                ),
              ),
              SwitchListTile(
                title: const Text('Force proceed'),
                value: force,
                onChanged: (v) => setState(() => force = v),
              )
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, CheckPreviewResult(confirm: false, forceIfFar: false)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Retake', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, CheckPreviewResult(confirm: true, forceIfFar: force)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
