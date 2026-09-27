import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/live_provider.dart';

class PickupStopScreen extends StatefulWidget {
  const PickupStopScreen({super.key});

  @override
  State<PickupStopScreen> createState() => _PickupStopScreenState();
}

class _PickupStopScreenState extends State<PickupStopScreen> {
  List<StopInfo> _stops = [];
  String? _selectedStopId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final stops = await context.read<LiveProvider>().loadStops();
      setState(() {
        _stops = stops;
        _selectedStopId = auth.user?.pickupStop?.id;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = humanizeError(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_selectedStopId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().updatePickup(_selectedStopId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup stop saved successfully.'),
          backgroundColor: AppTheme.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = humanizeError(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Select Pickup Stop'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.coral),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.coral)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: AppTheme.border)),
                        ),
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DESIGNATED BOARDING STOP',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose where you will board the campus bus. Driver arrival alerts and ETA calculations will adjust based on this stop.',
                              style: TextStyle(fontSize: 13, color: AppTheme.muted.withValues(alpha: 0.95), height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _stops.length,
                          separatorBuilder: (_, s) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final stop = _stops[i];
                            final isSelected = _selectedStopId == stop.id;
                            return Container(
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                border: Border.all(
                                  color: isSelected ? AppTheme.accent : AppTheme.border,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                                boxShadow: isSelected ? AppTheme.cardShadow : null,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                  onTap: () {
                                    setState(() => _selectedStopId = stop.id);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected ? AppTheme.accent : const Color(0xFFCBD5E1),
                                              width: isSelected ? 6.5 : 2,
                                            ),
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stop.name,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                  color: isSelected ? AppTheme.primary : AppTheme.navy,
                                                ),
                                              ),
                                              if (stop.code != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Stop Code: ${stop.code}',
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 22),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: AppTheme.border)),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                              ),
                            ),
                            onPressed: _selectedStopId == null || _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text('SAVE SELECTION', style: TextStyle(letterSpacing: 0.8, fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
