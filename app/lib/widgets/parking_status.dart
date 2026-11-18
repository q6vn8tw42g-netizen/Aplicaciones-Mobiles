import 'package:flutter/material.dart';

import '../models/espacio.dart';
import '../theme/estacionaya_theme.dart';

bool camaraVerificable(String id) => const {'CAM-001', 'CAM-005'}.contains(id);

/// Presentation of the existing provider heartbeat, including anonymous/stale reads.
String estadoVisible(Espacio e, {required bool sincronizado}) {
  if (!sincronizado || !camaraVerificable(e.camaraId)) return 'NO_VERIFICADO';
  return e.visionEnLinea ? e.estado : 'SIN_SERVICIO';
}

String etiquetaEstado(String estado) => switch (estado) {
      'LIBRE' => 'Libre',
      'OCUPADO' => 'Ocupado',
      'RESERVADO' => 'Reservado',
      'SIN_SERVICIO' => 'Sin servicio',
      'NO_VERIFICADO' => 'No verificado',
      _ => estado.replaceAll('_', ' '),
    };

Color colorEstado(String estado) => switch (estado) {
      'LIBRE' => EstacionaYaTokens.available,
      'OCUPADO' => EstacionaYaTokens.occupied,
      'RESERVADO' => EstacionaYaTokens.reserved,
      _ => EstacionaYaTokens.offline,
    };

IconData iconoEstado(String estado) => switch (estado) {
      'LIBRE' => Icons.local_parking_rounded,
      'OCUPADO' => Icons.directions_car_filled_rounded,
      'RESERVADO' => Icons.schedule_rounded,
      'NO_VERIFICADO' => Icons.question_mark_rounded,
      _ => Icons.remove_rounded,
    };
