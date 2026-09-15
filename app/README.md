# EstacionaYa — App móvil (Flutter)

Pantalla principal: mapa con los espacios coloreados por estado, lista de
espacios cercanos, y botones "Me estacioné aquí" / "Voy a salir". Antes de
eso, login/registro con Supabase Auth (obligatorio: las políticas RLS de
la base de datos exigen estar autenticado para leer los espacios).

## 1. Generar los proyectos nativos (Android/iOS)

Esta carpeta trae solo el código Dart (`lib/`) y `pubspec.yaml`. Le faltan
las carpetas `android/` e `ios/`, que Flutter genera automáticamente:

```bash
cd app
flutter create --project-name estacionaya .
```

Esto crea `android/`, `ios/`, etc. **sin tocar** tu carpeta `lib/` ni tu
`pubspec.yaml` (Flutter detecta que ya existen y no los sobreescribe).

## 2. Instalar dependencias

```bash
flutter pub get
```

## 3. Agregar los permisos necesarios

**Android** — en `android/app/src/main/AndroidManifest.xml`, dentro de
`<manifest>` (antes de `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**iOS** — en `ios/Runner/Info.plist`, dentro de `<dict>`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>EstacionaYa necesita tu ubicación para confirmar que estás junto al espacio que reportas.</string>
```

## 4. Configurar las URLs (Supabase + API)

Los valores por defecto en `lib/config.dart` usan `10.0.2.2`, que es como
el **emulador de Android** ve al `localhost` de tu PC. Ajusta según dónde
pruebes:

| Dónde corres la app          | Usa                                  |
| ----------------------------- | ------------------------------------- |
| Emulador Android              | `10.0.2.2` (ya es el valor por defecto) |
| Simulador iOS                 | `127.0.0.1` o `localhost`             |
| Celular físico (misma Wi-Fi)  | la IP local de tu PC, ej. `192.168.1.50` |

Puedes sobreescribirlas sin tocar el código:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.50:8000 \
  --dart-define=SUPABASE_URL=http://192.168.1.50:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

La llave `SUPABASE_PUBLISHABLE_KEY` es la que te muestra `supabase status`
(la misma pantalla donde sacaste la `Secret` para el backend — aquí usa
la **Publishable**, no la Secret).

## 5. Correr la app

Con un emulador o celular conectado:

```bash
flutter run
```

## Flujo esperado

1. Se abre en la pantalla de login → crea una cuenta con "¿No tienes
   cuenta? Regístrate".
2. Al registrarte, el trigger `on_auth_user_created` (ver
   `supabase/migrations/0001_init.sql`) crea automáticamente tu fila en
   `perfiles` con rol `CONDUCTOR` y 0 karma.
3. Entras a la pantalla principal: mapa, lista de espacios, botones de
   reporte. Si la tabla `espacios` sigue vacía, la lista se ve vacía —
   inserta las filas de prueba que ya vimos en el SQL Editor de Supabase.
4. Cuando el servicio de visión (o un reporte tuyo) cambie el estado de
   un espacio, la lista y el mapa se actualizan solos, sin recargar
   (Realtime).

## Pendiente / siguientes pasos

- Pantalla o botón visible solo para rol Validador/Admin que llame a
  `ApiService.forzarEstado` (RF5). Por ahora ese endpoint existe en el
  backend pero no tiene UI en la app.
- Manejo de permisos de ubicación denegados de forma más amigable
  (actualmente solo lanza un mensaje de error).
- Ícono y splash screen propios (por ahora usa los de Flutter por defecto).
