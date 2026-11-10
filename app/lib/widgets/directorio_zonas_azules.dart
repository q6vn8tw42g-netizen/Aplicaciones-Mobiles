import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/zonas_azules_oficiales.dart';
import '../theme/estacionaya_theme.dart';

/// Directorio documental: no implica disponibilidad de una plaza.
class DirectorioZonasAzules extends StatefulWidget {
  final bool esMontufar;
  const DirectorioZonasAzules({super.key, required this.esMontufar});

  @override
  State<DirectorioZonasAzules> createState() => _DirectorioZonasAzulesState();
}

class _DirectorioZonasAzulesState extends State<DirectorioZonasAzules> {
  String consulta = '';

  @override
  Widget build(BuildContext context) {
    final tramos = widget.esMontufar
        ? CatalogoZonasAzules.montufar
        : CatalogoZonasAzules.tulcan;
    final visibles = tramos.where((e) =>
        e.titulo.toLowerCase().contains(consulta.toLowerCase())).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          children: [
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: EstacionaYaTokens.outline,
                borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 16),
            Text('Tramos de zona azul · ${widget.esMontufar ? 'San Gabriel' : 'Tulcán'}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Catálogo basado en ordenanzas municipales. '
                'No representa plazas libres ni ocupación en tiempo real. '
                'Comprueba la señalización vigente en la calle.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: EstacionaYaTokens.muted)),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar calle o intersección',
                border: OutlineInputBorder()),
              onChanged: (text) => setState(() => consulta = text),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: visibles.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final tramo = visibles[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.local_parking_rounded)),
                    title: Text(tramo.calle),
                    subtitle: Text('Entre ${tramo.desde} y ${tramo.hasta}'),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => _buscarEnMapa(tramo),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buscarEnMapa(TramoZonaAzul tramo) async {
    final url = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': tramo.busqueda,
    });
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la búsqueda en Maps.')),
      );
    }
  }
}
