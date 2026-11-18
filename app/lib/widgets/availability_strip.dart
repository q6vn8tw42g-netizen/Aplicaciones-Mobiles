import 'package:flutter/material.dart';

import '../theme/estacionaya_theme.dart';

class AvailabilityStrip extends StatelessWidget {
  const AvailabilityStrip(
      {super.key,
      required this.total,
      required this.libres,
      required this.ocupados,
      required this.confirmado});

  final int total, libres, ocupados;
  final bool confirmado;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        total,
        'Total',
        EstacionaYaTokens.primary,
        EstacionaYaTokens.primarySoft,
        Icons.local_parking_rounded,
      ),
      (
        libres,
        'Libres',
        EstacionaYaTokens.available,
        EstacionaYaTokens.availableSoft,
        Icons.check_circle_outline_rounded
      ),
      (
        ocupados,
        'Ocupados',
        EstacionaYaTokens.occupied,
        EstacionaYaTokens.occupiedSoft,
        Icons.directions_car_outlined,
      ),
    ];
    return LayoutBuilder(builder: (context, limits) {
      final vertical =
          limits.maxWidth < MediaQuery.textScalerOf(context).scale(260);
      Widget cell(int i) {
        final (count, label, ink, background, icon) = items[i];
        final value = Text(confirmado ? '$count' : '—',
            style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w800,
                fontSize: 24,
                letterSpacing: -.8,
                height: 1.1));
        final title = Text(label,
            style: TextStyle(
                color: ink, fontWeight: FontWeight.w600, fontSize: 12));
        return Semantics(
            label: '$label, ${confirmado ? count : "sin confirmar"}',
            excludeSemantics: true,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                    color: background, borderRadius: BorderRadius.circular(14)),
                child: vertical
                    ? Row(children: [
                        Icon(icon, color: ink, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: title),
                        value,
                      ])
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  value,
                                  Icon(icon, color: ink, size: 17),
                                ]),
                            const SizedBox(height: 5),
                            title,
                          ])));
      }

      if (vertical) {
        return Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            cell(i)
          ]
        ]);
      }
      return Row(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: cell(i))
        ]
      ]);
    });
  }
}
