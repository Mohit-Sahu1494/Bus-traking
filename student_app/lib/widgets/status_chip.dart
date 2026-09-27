import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.busNumber});
  final String status;
  final String? busNumber;

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Color bg;
    Color borderColor;
    Color textColor;
    String label;

    switch (status.toUpperCase()) {
      case 'ACTIVE':
        dotColor = const Color(0xFF10B981);
        bg = const Color(0xFFECFDF5);
        borderColor = const Color(0xFFA7F3D0);
        textColor = const Color(0xFF047857);
        label = 'ACTIVE';
        break;
      case 'PAUSED':
        dotColor = const Color(0xFFF59E0B);
        bg = const Color(0xFFFEF3C7);
        borderColor = const Color(0xFFFDE68A);
        textColor = const Color(0xFFB45309);
        label = 'PAUSED';
        break;
      case 'OFFLINE':
        dotColor = const Color(0xFFEF4444);
        bg = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFFECACA);
        textColor = const Color(0xFFB91C1C);
        label = 'OFFLINE';
        break;
      default:
        dotColor = const Color(0xFF94A3B8);
        bg = const Color(0xFFF1F5F9);
        borderColor = const Color(0xFFE2E8F0);
        textColor = const Color(0xFF475569);
        label = 'INACTIVE';
    }

    final bus = busNumber != null && busNumber!.isNotEmpty ? busNumber! : 'BUS-04';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$bus  $label',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
