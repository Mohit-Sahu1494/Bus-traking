import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/errors.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';

Future<void> showBusSelectionSheet(BuildContext context) async {
  final trip = context.read<TripProvider>();
  final auth = context.read<AuthProvider>();

  if (trip.isActive || trip.isPaused) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot change bus while a trip is active. Please end the current trip first.'),
        backgroundColor: AppTheme.amber,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BusSelectionSheetContent(trip: trip, auth: auth),
  );
}

class _BusSelectionSheetContent extends StatefulWidget {
  const _BusSelectionSheetContent({required this.trip, required this.auth});
  final TripProvider trip;
  final AuthProvider auth;

  @override
  State<_BusSelectionSheetContent> createState() => _BusSelectionSheetContentState();
}

class _BusSelectionSheetContentState extends State<_BusSelectionSheetContent> {
  String? _selectedBusId;
  String? _selectedBusNumber;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    await widget.trip.fetchAvailableBuses();
    if (mounted) {
      final current = widget.trip.availableBuses.firstWhere(
        (b) => b['isCurrent'] == true,
        orElse: () => {},
      );
      if (current.isNotEmpty) {
        setState(() {
          _selectedBusId = current['id']?.toString();
          _selectedBusNumber = current['busNumber']?.toString();
        });
      }
    }
  }

  Future<void> _confirmAssignment() async {
    if (_selectedBusId == null) return;
    setState(() => _submitting = true);
    try {
      await widget.trip.assignBus(_selectedBusId!);
      await widget.auth.refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assigned vehicle updated to ${_selectedBusNumber ?? "selected bus"}.'),
          backgroundColor: AppTheme.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(humanizeError(e)),
            backgroundColor: AppTheme.coral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>();
    final buses = trip.availableBuses;
    final loading = trip.loadingBuses;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Bus',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.navy),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Choose a valid campus vehicle for your route',
                      style: TextStyle(fontSize: 13, color: AppTheme.muted),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.muted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (loading && buses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (buses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.directions_bus_filled_outlined, size: 40, color: AppTheme.muted),
                      const SizedBox(height: 10),
                      const Text(
                        'No campus buses available',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _loadBuses,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: buses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final b = buses[i];
                    final bId = b['id']?.toString() ?? '';
                    final bNum = b['busNumber']?.toString() ?? '';
                    final isCurrent = b['isCurrent'] == true;
                    final inUse = b['inUse'] == true && !isCurrent;
                    final reason = b['reason']?.toString() ?? 'Currently in use';
                    final isSelected = _selectedBusId == bId;

                    return InkWell(
                      onTap: inUse
                          ? null
                          : () {
                              setState(() {
                                _selectedBusId = bId;
                                _selectedBusNumber = bNum;
                              });
                            },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: inUse
                              ? const Color(0xFFF8FAFC)
                              : isSelected
                                  ? const Color(0xFFEFF6FF)
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: inUse
                                    ? const Color(0xFFE2E8F0)
                                    : isSelected
                                        ? AppTheme.primary
                                        : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.directions_bus,
                                size: 20,
                                color: inUse
                                    ? AppTheme.muted
                                    : isSelected
                                        ? Colors.white
                                        : AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        bNum,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: inUse ? AppTheme.muted : AppTheme.navy,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'CURRENT BUS',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.emerald,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (inUse) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      reason,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.coral,
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Available for route service',
                                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (inUse)
                              const Icon(Icons.block, color: AppTheme.muted, size: 20)
                            else if (isSelected)
                              const Icon(Icons.check_circle, color: AppTheme.primary, size: 24)
                            else
                              const Icon(Icons.radio_button_unchecked, color: AppTheme.muted, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _submitting || _selectedBusId == null ? null : _confirmAssignment,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Change Bus',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
