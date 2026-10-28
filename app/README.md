# EstacionaYa — Aplicación Flutter

La app muestra disponibilidad en el mapa y la lista, recibe cambios mediante Supabase Realtime, y ofrece reportes con ubicación GPS a conductores autenticados. El mapa puede consultarse sin cuenta. Validadores y administradores pueden ver historial y forzar estados desde cada espacio.

## Configuración

Desde `app/`:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_TU_CLAVE
```

Para una instalación Supabase remota usa su URL y clave publicable. Para un móvil físico, cambia `10.0.2.2` por la IP de la computadora en la red local. Los endpoints de FastAPI también deben ser alcanzables desde ese dispositivo. No pongas la clave secreta/service-role en Flutter.

La configuración pasa por `lib/config.dart`; `main.dart` inicializa Supabase con esos valores y `AuthGate` abre la app aun sin sesión. La sesión se solicita al reportar o abrir funciones de validador. El perfil se carga al iniciar/cambiar la sesión; crea roles `VALIDADOR` o `ADMIN` desde un contexto administrativo seguro.

Para habilitar un validador en el entorno de evaluación, primero registra su cuenta y ejecuta en Supabase SQL Editor, reemplazando el correo:

```sql
update public.perfiles p
set rol = 'VALIDADOR'
from auth.users u
where p.id = u.id and u.email = 'validador@ejemplo.com';
```

## Funciones incluidas

- Mapa centrado en Tulcán y lista de espacios con colores por estado.
- Contador de espacios libres que excluye `CAM-001` cuando la cámara está fuera de línea.
- Heartbeat de cámara por Realtime: `CAM-001` pasa a gris si no hay señal durante 3 segundos.
- Reportes «Me estacioné» y «Voy a salir» con verificación de cercanía en FastAPI.
- Panel de acciones por espacio para validadores/admins: historial y forzado con bloqueo temporal.
- Navegación a Google Maps y Waze.

## Permisos y plataformas

Los proyectos Android/iOS ya están generados. Comprueba `android/app/src/main/AndroidManifest.xml` e `ios/Runner/Info.plist` para permisos de internet y ubicación si los cambias; Flutter/geolocator necesita autorización de ubicación al reportar. En celular físico, permite conectividad de red hacia la API y Supabase.

## Verificación

```powershell
dart analyze lib test
flutter test
```

La prueba widget cubre el render del estado y los tests del provider revisan carga, actualizaciones Realtime, errores y conversión del modelo UUID. La integración final con Supabase y ubicación debe comprobarse en el emulador/dispositivo de evaluación.
