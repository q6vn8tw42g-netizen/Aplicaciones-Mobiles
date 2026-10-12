import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/espacio.dart';
import '../providers/espacios_provider.dart';
import '../services/navigation_service.dart';
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
            builder: (context, provider, child) {
              return Padding(
                padding: const EdgeInsets.only(
                  right: 12,
                ),
                child: Chip(
                  avatar: const Icon(
                    Icons.star,
                    size: 16,
                  ),
                  label: Text(
                    '${provider.puntosKarma} karma',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<EspaciosProvider>(
          builder: (context, provider, child) {
            if (provider.cargando) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (provider.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (provider.espacios.isEmpty) {
              return const Center(
                child: Text(
                  'No existen espacios disponibles.',
                ),
              );
            }

            return Column(
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: MapaEspacios(
                    espacios: provider.espacios,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    4,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Espacios cercanos',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      4,
                      12,
                      16,
                    ),
                    itemCount:
                        provider.espacios.length,
                    separatorBuilder:
                        (context, index) {
                      return const SizedBox(
                        height: 8,
                      );
                    },
                    itemBuilder: (context, indice) {
                      final espacio =
                          provider.espacios[indice];

                      return EspacioCard(
                        espacio: espacio,
                        onNavegar: () {
                          _mostrarOpcionesNavegacion(
                            context,
                            espacio,
                          );
                        },
                        onReportar: (tipo) {
                          _reportar(
                            context,
                            espacio,
                            tipo,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _mostrarOpcionesNavegacion(
    BuildContext context,
    Espacio espacio,
  ) async {
    final latitud = espacio.latitud;
    final longitud = espacio.longitud;

    if (latitud == null || longitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este espacio no tiene ubicación.',
          ),
        ),
      );
      return;
    }

    final opcion =
        await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (contextoModal) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  12,
                ),
                child: Text(
                  'Cómo llegar a ${espacio.nombre}',
                  style: Theme.of(contextoModal)
                      .textTheme
                      .titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Google Maps'),
                subtitle: const Text(
                  'Abrir la ruta en Google Maps',
                ),
                onTap: () {
                  Navigator.pop(
                    contextoModal,
                    'google',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.navigation,
                ),
                title: const Text('Waze'),
                subtitle: const Text(
                  'Abrir la ruta en Waze',
                ),
                onTap: () {
                  Navigator.pop(
                    contextoModal,
                    'waze',
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (opcion == null) {
      return;
    }

    try {
      if (opcion == 'google') {
        await NavigationService.abrirGoogleMaps(
          latitud: latitud,
          longitud: longitud,
        );
      } else if (opcion == 'waze') {
        await NavigationService.abrirWaze(
          latitud: latitud,
          longitud: longitud,
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  Future<void> _reportar(
    BuildContext context,
    Espacio espacio,
    String tipo,
  ) async {
    final provider =
        context.read<EspaciosProvider>();

    final mensajero =
        ScaffoldMessenger.of(context);

    try {
      await provider.reportar(
        espacio,
        tipo,
      );

      mensajero.showSnackBar(
        const SnackBar(
          content: Text(
            'Reporte registrado.',
          ),
        ),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }
}