import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Programa y cancela el aviso local asociado a una reserva.
class ReservaNotificationService {
  ReservaNotificationService._();

  static final ReservaNotificationService instance =
      ReservaNotificationService._();

  static const Duration avisoAntesDeExpirar = Duration(minutes: 2);
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'estacionaya_reservas',
    'Reservas de estacionamiento',
    channelDescription: 'Avisos de expiración de reservas de parqueo.',
    importance: Importance.high,
    priority: Priority.high,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _inicializacion;

  Future<void> inicializar() => _inicializacion ??= _inicializar();

  Future<void> _inicializar() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
  }

  /// Devuelve false si el usuario no autorizó las notificaciones.
  Future<bool> programarAviso({
    required String espacioId,
    required DateTime expiracion,
  }) async {
    try {
      await inicializar();
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (android == null) return false;
        final permisosAvisos = await android.requestNotificationsPermission();
        if (permisosAvisos != true) return false;

        var puedeProgramarExacta =
            await android.canScheduleExactNotifications() ?? false;
        if (!puedeProgramarExacta) {
          await android.requestExactAlarmsPermission();
          puedeProgramarExacta =
              await android.canScheduleExactNotifications() ?? false;
        }

        final notificarEn = expiracion.subtract(avisoAntesDeExpirar);
        if (!notificarEn.isAfter(DateTime.now())) return false;
        await _plugin.zonedSchedule(
          _idDe(espacioId),
          'Tu reserva está por expirar',
          'Te quedan 2 minutos para ocupar tu espacio.',
          tz.TZDateTime.from(notificarEn.toUtc(), tz.UTC),
          const NotificationDetails(android: _androidDetails),
          androidScheduleMode: puedeProgramarExacta
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          payload: espacioId,
        );
        return true;
      }

      if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final permitido = await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        if (!permitido) return false;
        final notificarEn = expiracion.subtract(avisoAntesDeExpirar);
        if (!notificarEn.isAfter(DateTime.now())) return false;
        await _plugin.zonedSchedule(
          _idDe(espacioId),
          'Tu reserva está por expirar',
          'Te quedan 2 minutos para ocupar tu espacio.',
          tz.TZDateTime.from(notificarEn.toUtc(), tz.UTC),
          const NotificationDetails(iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: espacioId,
        );
        return true;
      }
    } catch (error, stackTrace) {
      debugPrint('No se pudo programar el aviso de reserva: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return false;
  }

  Future<void> cancelarAviso(String espacioId) async {
    try {
      await inicializar();
      await _plugin.cancel(_idDe(espacioId));
    } catch (error) {
      debugPrint('No se pudo cancelar el aviso de reserva: $error');
    }
  }

  /// Limpia avisos que quedaron programados pero ya no corresponden a reservas activas.
  Future<void> reconciliarAvisos(Set<String> reservasActivas) async {
    try {
      await inicializar();
      final pendientes = await _plugin.pendingNotificationRequests();
      for (final pendiente in pendientes) {
        final espacioId = pendiente.payload;
        if (espacioId != null && !reservasActivas.contains(espacioId)) {
          await _plugin.cancel(pendiente.id);
        }
      }
    } catch (error) {
      debugPrint('No se pudieron reconciliar avisos de reserva: $error');
    }
  }

  int _idDe(String espacioId) {
    var hash = 0;
    for (final unit in espacioId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
