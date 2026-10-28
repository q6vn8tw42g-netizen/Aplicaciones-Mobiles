import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/espacio.dart';
import '../providers/espacios_provider.dart';
import '../services/navigation_service.dart';
import '../services/api_service.dart';
import '../theme/estacionaya_theme.dart';
import '../widgets/espacio_card.dart';
import '../widgets/mapa_espacios.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _espacioSeleccionadoId;
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabIndex == 0
          ? Consumer<EspaciosProvider>(
              builder: (context, provider, child) {
                final espacios = _ordenarEspacios(provider.espaciosVisibles);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    MapaEspacios(
                      espacios: espacios,
                      espacioSeleccionadoId: _espacioSeleccionadoId,
                      onEspacioSeleccionado: (espacio) =>
                          _seleccionarEspacio(context, espacio),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: _HeaderFlotante(
                            provider: provider,
                            onSesion: () => _gestionarSesion(context, provider),
                          ),
                        ),
                      ),
                    ),
                    DraggableScrollableSheet(
                      initialChildSize: 0.36,
                      minChildSize: 0.23,
                      maxChildSize: 0.84,
                      snap: true,
                      snapSizes: const [0.36, 0.84],
                      builder: (context, scrollController) {
                        final cantidad = espacios.length;
                        final mostrarEstado =
                            provider.error != null || espacios.isEmpty;
                        return Container(
                          decoration: const BoxDecoration(
                            color: EstacionaYaTokens.surface,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(EstacionaYaTokens.radius24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x260F172A),
                                blurRadius: 24,
                                offset: Offset(0, -5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(EstacionaYaTokens.radius24),
                            ),
                            child: ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                MediaQuery.paddingOf(context).bottom + 16,
                              ),
                              itemCount: cantidad + 2 + (mostrarEstado ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return _EncabezadoPanel(
                                    cantidad: cantidad,
                                    cargando: provider.cargando,
                                    error: provider.error != null,
                                  );
                                }
                                if (index == 1) {
                                  return _FiltrosVehiculo(
                                    seleccionado: provider.filtroVehiculo,
                                    onSeleccionar:
                                        provider.seleccionarFiltroVehiculo,
                                  );
                                }
                                if (mostrarEstado && index == 2) {
                                  return _EstadoLista(
                                    cargando: provider.cargando,
                                    conError: provider.error != null,
                                  );
                                }
                                final indiceEspacio =
                                    index - 2 - (mostrarEstado ? 1 : 0);
                                final espacio = espacios[indiceEspacio];
                                final puedeCancelar = provider.reservasPropias
                                        .contains(espacio.id) ||
                                    provider.rol?.toLowerCase() == 'admin';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: EspacioCard(
                                    espacio: espacio,
                                    seleccionado:
                                        espacio.id == _espacioSeleccionadoId,
                                    onSeleccionar: () =>
                                        _seleccionarEspacio(context, espacio),
                                    puedeAdministrar: provider.rol
                                                ?.toLowerCase() ==
                                            'validador' ||
                                        provider.rol?.toLowerCase() == 'admin',
                                    onVerHistorial: () =>
                                        _verHistorial(context, espacio),
                                    onForzar: () =>
                                        _forzarEstado(context, espacio),
                                    onNavegar: () => _mostrarOpcionesNavegacion(
                                        context, espacio),
                                    onReservar: () =>
                                        _reservar(context, provider, espacio),
                                    onCancelarReserva: puedeCancelar
                                        ? () => _cancelarReserva(
                                            context, provider, espacio)
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            )
          : _buildSecondaryTab(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Mapa'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Mi Perfil'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Ajustes'),
        ],
      ),
    );
  }

  Widget _buildSecondaryTab(BuildContext context) => Consumer<EspaciosProvider>(
        builder: (context, provider, _) {
          final session = Supabase.instance.client.auth.currentSession;
          if (_tabIndex == 1) {
            return SafeArea(
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircleAvatar(
                          radius: 32, child: Icon(Icons.person, size: 32)),
                      const SizedBox(height: 12),
                      Text(session?.user.email ?? 'Modo visitante',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(provider.rol ?? 'Estudiante / visitante',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      Text(
                          'Espacios libres en línea: ${provider.espacios.where((e) => e.visionEnLinea && e.estado == 'LIBRE').length}'),
                    ]),
                  ),
                ),
              ),
            );
          }
          return SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Text('Ajustes',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const ListTile(
                  leading: Icon(Icons.notifications_outlined),
                  title: Text('Notificaciones'),
                  subtitle: Text('Preferencias de avisos de disponibilidad')),
              const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Acerca de EstacionaYa'),
                  subtitle:
                      Text('Disponibilidad de parqueos UPEC en tiempo real')),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  if (session == null) {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen()));
                    if (context.mounted) await provider.cargarReservasPropias();
                  } else {
                    await Supabase.instance.client.auth.signOut();
                    provider.limpiarReservasPropias();
                    if (context.mounted) setState(() {});
                  }
                },
                icon: Icon(session == null ? Icons.login : Icons.logout),
                label:
                    Text(session == null ? 'Iniciar sesión' : 'Cerrar sesión'),
              ),
            ]),
          );
        },
      );

  List<Espacio> _ordenarEspacios(List<Espacio> espacios) {
    final ordenados = List<Espacio>.of(espacios);
    final seleccionado = ordenados.indexWhere(
      (espacio) => espacio.id == _espacioSeleccionadoId,
    );
    if (seleccionado > 0) {
      final espacio = ordenados.removeAt(seleccionado);
      ordenados.insert(0, espacio);
    }
    return ordenados;
  }

  Future<void> _seleccionarEspacio(
    BuildContext context,
    Espacio espacio,
  ) async {
    setState(() => _espacioSeleccionadoId = espacio.id);
    if (espacio.estado == 'LIBRE' && espacio.visionEnLinea) {
      await _mostrarOpcionesNavegacion(context, espacio);
    }
  }

  Future<void> _reservar(
    BuildContext context,
    EspaciosProvider provider,
    Espacio espacio,
  ) async {
    if (Supabase.instance.client.auth.currentSession == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      if (!context.mounted ||
          Supabase.instance.client.auth.currentSession == null) {
        return;
      }
    }
    try {
      final avisoProgramado = await provider.reservar(espacio);
      if (context.mounted) {
        _mostrarMensaje(
          context,
          avisoProgramado
              ? 'Espacio reservado por 5 minutos. Te avisaremos cuando falten 2.'
              : 'Espacio reservado por 5 minutos. Activa las notificaciones para recibir el aviso de expiración.',
        );
      }
    } catch (error) {
      if (context.mounted) _mostrarMensaje(context, error.toString());
    }
  }

  Future<void> _cancelarReserva(
    BuildContext context,
    EspaciosProvider provider,
    Espacio espacio,
  ) async {
    try {
      await provider.cancelarReserva(espacio);
      if (context.mounted) _mostrarMensaje(context, 'Reserva cancelada.');
    } catch (error) {
      if (context.mounted) _mostrarMensaje(context, error.toString());
    }
  }

  Future<void> _gestionarSesion(
    BuildContext context,
    EspaciosProvider provider,
  ) async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      if (context.mounted) await provider.cargarReservasPropias();
    } else {
      await auth.signOut();
      provider.limpiarReservasPropias();
    }
  }

  Future<void> _verHistorial(BuildContext context, Espacio espacio) async {
    try {
      final eventos = await ApiService().obtenerHistorial(espacio.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Historial · ${espacio.nombre}'),
          content: SizedBox(
            width: 420,
            child: eventos.isEmpty
                ? const Text(
                    'Este espacio todavía no tiene cambios registrados.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: eventos.length,
                    itemBuilder: (context, index) {
                      final evento = eventos[index];
                      final anterior = evento['estado_anterior'] ?? 'INICIAL';
                      final fecha = evento['creado_en']?.toString() ?? '';
                      return ListTile(
                        dense: true,
                        title: Text('$anterior → ${evento['estado_nuevo']}'),
                        subtitle: Text('${evento['fuente']} · $fecha'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) _mostrarMensaje(context, error.toString());
    }
  }

  Future<void> _forzarEstado(BuildContext context, Espacio espacio) async {
    var minutos = 30;
    final estado = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Forzar · ${espacio.nombre}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Marcar libre'),
                leading: const Icon(Icons.check_circle, color: Colors.green),
                onTap: () => Navigator.pop(dialogContext, 'LIBRE'),
              ),
              ListTile(
                title: const Text('Marcar ocupado'),
                leading: const Icon(Icons.cancel, color: Colors.red),
                onTap: () => Navigator.pop(dialogContext, 'OCUPADO'),
              ),
              Row(
                children: [
                  const Expanded(child: Text('Bloqueo (minutos)')),
                  DropdownButton<int>(
                    value: minutos,
                    items: const [15, 30, 60, 120]
                        .map(
                          (value) => DropdownMenuItem(
                              value: value, child: Text('$value')),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => minutos = value);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
    if (estado == null || !context.mounted) return;
    try {
      await ApiService().forzarEstado(
        espacioId: espacio.id,
        estado: estado,
        minutosBloqueo: minutos,
      );
      if (context.mounted) {
        _mostrarMensaje(context, 'Estado forzado por $minutos minutos.');
      }
    } catch (error) {
      if (context.mounted) _mostrarMensaje(context, error.toString());
    }
  }

  void _mostrarMensaje(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
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

    final opcion = await showModalBottomSheet<String>(
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
                  style: Theme.of(contextoModal).textTheme.titleMedium,
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
}

class _FiltrosVehiculo extends StatelessWidget {
  final String seleccionado;
  final ValueChanged<String> onSeleccionar;

  const _FiltrosVehiculo({
    required this.seleccionado,
    required this.onSeleccionar,
  });

  static const _opciones = <(String, String)>[
    ('TODOS', 'Todos'),
    ('MOTO', 'Moto'),
    ('AUTO', 'Auto'),
    ('CAMIONETA', 'Camioneta'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _opciones.map((opcion) {
              final activo = seleccionado == opcion.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(opcion.$2),
                  selected: activo,
                  onSelected: (_) => onSeleccionar(opcion.$1),
                ),
              );
            }).toList(),
          ),
        ),
      );
}

class _HeaderFlotante extends StatelessWidget {
  final EspaciosProvider provider;
  final VoidCallback onSesion;

  const _HeaderFlotante({required this.provider, required this.onSesion});

  @override
  Widget build(BuildContext context) {
    final disponibles = provider.espaciosVisibles
        .where((e) => e.estado == 'LIBRE' && e.visionEnLinea)
        .length;
    final sesion = Supabase.instance.client.auth.currentSession;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(EstacionaYaTokens.radius20),
        border: Border.all(color: EstacionaYaTokens.outline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: EstacionaYaTokens.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_parking_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EstacionaYa',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tulcán · disponibilidad en vivo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$disponibles libres',
              style: const TextStyle(
                color: EstacionaYaTokens.available,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: sesion == null ? 'Iniciar sesión' : 'Cerrar sesión',
            onPressed: onSesion,
            icon: Icon(
                sesion == null ? Icons.person_rounded : Icons.logout_rounded),
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: EstacionaYaTokens.primary,
              backgroundColor: EstacionaYaTokens.primarySoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _EncabezadoPanel extends StatelessWidget {
  final int cantidad;
  final bool cargando;
  final bool error;

  const _EncabezadoPanel({
    required this.cantidad,
    required this.cargando,
    required this.error,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Espacios cercanos',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        error
                            ? 'Conexión interrumpida · datos recientes'
                            : '$cantidad ubicaciones · elige un espacio para ver acciones',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (cargando)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else if (!error)
                  const Icon(
                    Icons.near_me_rounded,
                    color: EstacionaYaTokens.primary,
                  ),
              ],
            ),
          ],
        ),
      );
}

class _EstadoLista extends StatelessWidget {
  final bool cargando;
  final bool conError;

  const _EstadoLista({required this.cargando, required this.conError});

  @override
  Widget build(BuildContext context) {
    final icono = cargando
        ? Icons.radar_rounded
        : conError
            ? Icons.cloud_off_rounded
            : Icons.local_parking_rounded;
    final texto = cargando
        ? 'Buscando espacios disponibles…'
        : conError
            ? 'No se pudo actualizar el mapa. Revisa tu conexión.'
            : 'Aún no hay espacios en esta zona.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: EstacionaYaTokens.canvas,
          borderRadius: BorderRadius.circular(EstacionaYaTokens.radius16),
        ),
        child: Row(
          children: [
            Icon(icono, color: EstacionaYaTokens.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    );
  }
}
