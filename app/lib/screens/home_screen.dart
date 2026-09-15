import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/espacio.dart';
import '../providers/espacios_provider.dart';
import '../widgets/espacio_card.dart';
import '../widgets/mapa_espacios.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EstacionaYa'),
        actions: [
          Consumer<EspaciosProvider>(
            builder: (context, provider, _) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: const Icon(Icons.star, size: 16),
                label: Text('${provider.puntosKarma} karma'),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<EspaciosProvider>(
        builder: (context, provider, _) {
          if (provider.cargando) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text(provider.error!));
          }

          return Column(
            children: [
              SizedBox(
                height: 220,
                child: MapaEspacios(espacios: provider.espacios),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Espacios cercanos',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: provider.espacios.length,
                  itemBuilder: (context, indice) {
                    final espacio = provider.espacios[indice];
                    return EspacioCard(
                      espacio: espacio,
                      onReportar: (tipo) => _reportar(context, espacio, tipo),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _reportar(BuildContext context, Espacio espacio, String tipo) async {
    final provider = context.read<EspaciosProvider>();
    final mensajero = ScaffoldMessenger.of(context);

    try {
      await provider.reportar(espacio, tipo);
      mensajero.showSnackBar(const SnackBar(content: Text('Reporte registrado.')));
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
