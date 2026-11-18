import 'package:flutter/material.dart';

import '../theme/estacionaya_theme.dart';

/// Marca vectorial local; no requiere imágenes ni fuentes descargadas.
class EstacionaYaMark extends StatelessWidget {
  const EstacionaYaMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: EstacionaYaTokens.primary,
            borderRadius: BorderRadius.circular(size * .3),
          ),
          child: Stack(children: [
            Center(
                child: Icon(Icons.local_parking_rounded,
                    color: Colors.white, size: size * .65)),
            Positioned(
                right: size * .13,
                bottom: size * .13,
                child: Container(
                    width: size * .14,
                    height: size * .14,
                    decoration: const BoxDecoration(
                        color: Color(0xFFBFDBFE), shape: BoxShape.circle))),
          ]),
        ),
      );
}

/// Información sin acciones: evita aparentar ajustes que no están implementados.
class EstacionaYaInfoTile extends StatelessWidget {
  const EstacionaYaInfoTile(
      {super.key,
      required this.icon,
      required this.title,
      required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: EstacionaYaTokens.primarySoft,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: EstacionaYaTokens.primary)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ])),
        ]),
      );
}

class ParkingEmptyState extends StatelessWidget {
  const ParkingEmptyState(
      {super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
            color: EstacionaYaTokens.canvas,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: EstacionaYaTokens.outline)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(
              child: SizedBox.square(
                  dimension: 64,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: EstacionaYaTokens.primary
                                    .withValues(alpha: .12)))),
                    const CircleAvatar(
                        radius: 25,
                        backgroundColor: EstacionaYaTokens.primarySoft,
                        child: Icon(Icons.location_searching_rounded,
                            size: 25, color: EstacionaYaTokens.primary)),
                  ]))),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

/// Presentación de la sesión recibida; no accede a autenticación ni a providers.
class EstacionaYaProfileCard extends StatelessWidget {
  const EstacionaYaProfileCard(
      {super.key, required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: EstacionaYaTokens.night,
            borderRadius: BorderRadius.circular(24),
            boxShadow: EstacionaYaTokens.softShadow),
        child: Stack(children: [
          Positioned(
              right: -34,
              top: -42,
              child: ExcludeSemantics(
                  child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: .07),
                              width: 28))))),
          Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .2))),
                          child: const CircleAvatar(
                              radius: 26,
                              backgroundColor: Color(0xFFEBF2FF),
                              child: Icon(Icons.person_outline_rounded,
                                  size: 30, color: EstacionaYaTokens.night))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text('TU CUENTA',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: const Color(0xFFBFDBFE)))),
                    ]),
                    const SizedBox(height: 24),
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(description,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: const Color(0xFFD8E4F5))),
                    const SizedBox(height: 22),
                    const Divider(color: Color(0xFF3C526B)),
                    const SizedBox(height: 14),
                    const Row(children: [
                      EstacionaYaMark(size: 24),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('EstacionaYa',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600))),
                    ]),
                  ])),
        ]),
      );
}
