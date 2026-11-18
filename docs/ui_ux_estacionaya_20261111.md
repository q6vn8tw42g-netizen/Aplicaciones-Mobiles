# Evolución visual de EstacionaYa

Fecha: 11 de noviembre de 2026. Rama local: `codex/estacionaya-ui-ux`.
Base: `54f05df`. Se conservaron las modificaciones locales previas de
`pubspec.yaml`, `pubspec.lock` y el test de autenticación. No se hizo commit ni push.
Punto de recuperación de la interfaz: `tmp/ui_ux_before_20261111/`.

## Diagnóstico y decisiones

La pantalla principal vigente muestra catálogo de zonas azules y espacios monitoreados.
Usa una tarjeta propia en HomeScreen además del componente EspacioCard. Las filas
con nombre, estado y acción competían por el ancho de teléfonos pequeños. Los estilos
de inputs, paneles y navegación estaban repartidos. El modal de detalle decía “En vivo”
sin vincular esa etiqueta a una señal de cámara. Los modales largos no tenían desplazamiento.

Se mantuvo la composición mapa + encabezado + panel deslizable y las acciones existentes.
El trabajo mejora jerarquía, superficies, campos, lectura de estados, adaptación y
retroalimentación visual. No añade acciones de reservas ni nuevas rutas.

## Mejoras visuales

| Antes | Después |
|---|---|
| Tarjeta de Home con información en una fila | Encabezado, estado y señal separados; texto que puede ajustarse al ancho |
| Diferencias de estilo entre formularios y paneles | Tokens existentes y tema Material 3 compartido para inputs, botones, paneles y navegación |
| Etiqueta fija “En vivo” en detalle | Indicador de lectura con procedencia explícita y estado neutral si no puede verificarse |
| Detalles largos sin scroll | Modales desplazables sin cambiar sus acciones |
| Animación siempre activa | Transiciones de 180 ms y panel de 420 ms; reducción de movimiento respetada |
| Ocupación como información principal aislada | Nombre, cámara, estado, vehículo cuando existe y fecha del estado con etiquetas diferenciadas |

La fecha “Estado actualizado” corresponde a `actualizadoEn`; se presenta como información
del estado del puesto y nunca se usa como prueba de conexión. Los pines y sus geometrías
no se modificaron. La identidad azul y los colores semánticos se conservaron.

## Archivos de aplicación

- `app/lib/theme/estacionaya_theme.dart`: inputs, paneles, navegación, botones segmentados y sombras compartidas.
- `app/lib/screens/home_screen.dart`: integra las tarjetas y el indicador; mejora superficies y hace desplazables los detalles.
- `app/lib/widgets/parking_summary_card.dart`: nueva presentación reutilizable de la tarjeta real de Home; conserva el callback del detalle.
- `app/lib/widgets/camera_connection_badge.dart`: componentes de lectura para una cámara y el resumen de cámaras de la vista.
- `app/lib/widgets/espacio_card.dart`: jerarquía adaptable y transición del badge; conserva callbacks y controles existentes.
- `app/lib/screens/login_screen.dart`: texto introductorio coherente con zonas y espacios monitoreados; mismo flujo de Auth.
- `app/lib/screens/splash_screen.dart`: respeta reducción de movimiento; conserva icono, temporizador y destino.

## Procedencia del indicador de cámara

`EspaciosProvider` ya escucha `vision_heartbeat.ultimo_contacto` y actualiza
`Espacio.visionEnLinea`. La revisión encontró verificación específica para
`CAM-001` (ventana de 3 segundos) y `CAM-005` (10 segundos). Para otros IDs el modelo
puede conservar el valor predeterminado `true`; por eso ese booleano por sí solo no
se trata como evidencia de conexión para otras cámaras.

- Cámara conocida, flag vigente y sin carga/error: “Cámara activa”, verde.
- Cámara conocida con flag falso: “Sin señal vigente”, neutral.
- Cámara sin verificación soportada, carga o error de sincronización: “Conexión no verificada”, gris.

El componente no consulta tablas, no modifica el Provider y no crea heartbeats.
No infiere conexión desde internet, ocupación o `updated_at`. El Provider no expone
el timestamp ni distingue ausencia inicial de heartbeat y expiración. Por ello no
se asegura “desconectada” ni se muestra una antigüedad inventada. Ampliar a otros IDs
o distinguir esas causas requiere otra fase de datos; el rediseño no la implementa.
El detalle lee el flag actual del Provider mientras está abierto.

## Verificación realizada

| Comprobación | Resultado |
|---|---|
| `flutter pub get` | Correcto; sin agregar dependencias; hashes de ambos pubspec iguales a la copia previa |
| `flutter analyze` | Sin errores ni warnings; cuatro avisos informativos preexistentes de estilo; retorno 1 por esos avisos |
| `flutter test` | 12 pruebas aprobadas: seis existentes y seis de contrato visual/adaptación |
| Vista previa opcional con fuentes e iconos locales | Seis casos aprobados; imagen inspeccionada visualmente |
| `flutter build apk --debug` | Correcto; `app/build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --check` | Sin errores |
| Comparación de archivos protegidos | Mismos hashes para Provider, modelo, servicios, mapa, main, config y pubspec |

Los casos nuevos verifican que un ID sin soporte no se marque activo; que carga/error
invaliden el verde; que ambos IDs soportados reflejen el flag; y que la tarjeta preserve
su callback sin overflow a 320 px con texto 2×. Login y Registro se renderizaron a 320 px
con texto 1,5× e insets de teclado simulados. La prueba de galería incluye reducción de movimiento.

La imagen `output/ui_estacionaya_preview.png` es una vista de componentes con datos
sintéticos, no una captura de disponibilidad real ni del mapa completo. Para regenerarla
en este entorno Windows: `flutter test --dart-define=UI_PREVIEW=true --update-goldens test/ui_contract_test.dart`.

## Funcionalidades conservadas y límites de la comprobación

Se preservaron fuentes, coordenadas, geometrías, filtros, selección de ciudad, búsqueda,
ordenamiento, callbacks de detalle/navegación, controles de cartografía de desarrollo,
sesión y reglas de autenticación. Backend, visión, SQL y servicios no presentan diferencias
producidas por este trabajo. La revisión de código y las pruebas respaldan la conservación
de estas conexiones; no equivalen a una sesión física de cámara.

No había Android conectado; Flutter detectó Windows y Edge. No se ejecutaron en esta fase
un inicio de sesión remoto real, una sesión de detección EZVIZ, un cambio Realtime real,
interacción del mapa en un teléfono ni instalación del APK. Esas verificaciones quedan
para el dispositivo del usuario. No se afirma que hayan pasado.

Pendientes de estilo previos: llaves en `home_screen.dart` y dos condiciones de
`api_service.dart`, y un constructor que admite `const`. No bloquean la compilación del APK.
