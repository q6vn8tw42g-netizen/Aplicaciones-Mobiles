# EstacionaYa — rediseño de presentación (12/11/2026)

## Auditoría previa

- Aplicación Flutter en `app/`. `main.dart` aplica `EstacionaYaTheme.light` y abre `SplashScreen`; esta navega a `AuthGate` y después a `HomeScreen`.
- `HomeScreen` contiene las tres pestañas (índices 0 Mapa, 1 Perfil, 2 Ajustes), búsqueda, filtro de cercanía, GPS, selección, panel deslizable y modales de detalle/navegación. Perfil conserva la ruta `MaterialPageRoute` a `LoginScreen`; registro se abre desde login.
- Presentación reutilizable: `AvailabilityStrip`, `ParkingSummaryCard`, `CameraConnectionBadge`, `EspacioCard` y tema compartido. `parking_status.dart` traduce la disponibilidad según sincronización/heartbeat: se mantiene intacto.
- `MapaEspacios` usa `flutter_map` 7, teselas OpenStreetMap, `MapController`, marcadores agrupados y coordenadas de los modelos. Se mantiene íntegro, incluidos sus eventos, zoom y agrupaciones.
- `EspaciosProvider` administra streams, filtros de vehículo, reservas, perfil, roles y heartbeat. Ventanas actuales: CAM-001 3 s y CAM-005 10 s, temporizador 700 ms. No se modifican.
- `SupabaseService` consulta `espacios`/`perfiles` y suscripciones; `ApiService` gestiona reportes, reservas y validación. `NavigationService` conserva Google Maps/Waze. Los servicios, modelos, backend, visión y configuración quedan fuera de la edición.
- La lista actual se filtra por búsqueda/radio y conserva los registros ANTIZANA sin GPS. Los contadores proceden de esa lista y de `_estadoActual`; no se cambian ni se agregan datos.
- El panel móvil conserva su `DraggableScrollableController`, controlador de scroll de la lista, límites .19/.36/.95 y snap; escritorio conserva el panel lateral de 430 px desde 900 px.
- Los estados de carga, error y vacío ya están disponibles en el provider. Se cambia su presentación manteniendo las condiciones originales.

## Estado inicial y riesgos

Había cambios locales previos en Android, pantallas, tema, navegación, mapa, tarjetas y dependencias, además de archivos no rastreados. No se revierten ni se atribuyen a este trabajo. Copia previa de `lib/`, `test/`, estado Git y hashes en `tmp/premium_ui_20261112_baseline/`.

El riesgo principal es que `home_screen.dart` mezcla UI y lógica: las ediciones se acotan a árboles de widgets; filtros, controladores, callbacks y métodos de acciones se comparan con la copia previa. Otro riesgo es el desbordamiento con texto ampliado: se conservan superficies desplazables y se adaptan las tarjetas con `LayoutBuilder`, `Expanded` y `Wrap`. No se añaden fuentes ni dependencias que necesiten descarga.

## Dirección visual

Azul marino #142B49, azul #2563EB, fondo #F6F8FC y superficies blancas. Verde y rojo distinguen disponibilidad, acompañados de texto e iconos. Encabezado compacto claro, marca vectorial Flutter, panel con jerarquía editorial y estadísticas compactas, tarjetas de estado legibles, perfil con identidad marina y ajustes informativos agrupados. Material 3, radios 12/16/24, sombras suaves y animaciones que respetan movimiento reducido.

## Verificación

- `flutter analyze --no-pub`: 0 errores, 0 advertencias, 2 mensajes **info** (`curly_braces_in_flow_control_structures` en `lib/services/api_service.dart`, líneas 34 y 44). Flutter devuelve código 1 debido a esos mensajes. El análisis independiente de la copia inicial produce los mismos dos mensajes; no se silencian ni se edita el servicio.
- `dart format --output=none --set-exit-if-changed` sobre los seis archivos Dart de esta entrega: 0 cambios pendientes, código 0.
- `flutter test --no-pub --reporter expanded`: **23 pruebas correctas**, código 0. Incluye las pruebas existentes de autenticación, navegación con GPS simulado, disponibilidad por streams de prueba, heartbeat y tarjetas, más cuatro regresiones de esta entrega.
- Las nuevas regresiones cubren expansión del panel por arrastre, búsqueda y limpieza, carga/error/vacío, Perfil/Ajustes a 320 px con texto al 200 %, acceso a la ruta original de login y correo largo en el componente de sesión. Los problemas iniciales de las pruebas nuevas eran de scroll/layout diferido del propio test y se corrigieron esperando el siguiente render.
- `git diff --check`: correcto. Se revisó `git diff` y el diff directo contra la copia inicial, para distinguir las ediciones previas del usuario.
- Comparación SHA-256 del inventario inicial: únicamente cambiaron los cuatro archivos existentes de presentación enumerados abajo. Mapa, providers, servicios, modelos, autenticación, Android/iOS, backend, SQL y visión conservan los hashes iniciales. Los archivos nuevos se enumeran por separado.
- Comparación exacta de secciones de `HomeScreen`: estado/filtros/GPS/dispose, estados/selección/navegación/detalle, método `_sesion`, parámetros de `MapaEspacios` y configuración/controladores del panel permanecen idénticos. Evidencia en `tmp/premium_ui_20261112_logic_check.json`.
- Las pruebas de widgets bloquean solicitudes HTTP de teselas y registran respuestas 400 locales del entorno de pruebas. No prueban la conexión real con OpenStreetMap ni Supabase y no necesitan servicios externos.
- Inspección de imágenes locales de widgets para Perfil, Ajustes y panel sin registros en `tmp/premium_ui_20261112_previews/`. Son capturas del entorno de pruebas, con fuentes de Windows y mapa sin teselas; no son capturas Android ni evidencias de conectividad.

## Archivos de la entrega

Existentes modificados:

1. `app/lib/screens/home_screen.dart`: encabezado compacto, control flotante, panel, estados, Perfil, Ajustes y separación visual de la navegación. Se conservan las acciones, índices y rutas.
2. `app/lib/theme/estacionaya_theme.dart`: paleta, tipografía, superficies, navegación, botones, divisores e indicadores compartidos. Se conservan los colores semánticos accesibles de los estados.
3. `app/lib/widgets/availability_strip.dart`: iconos, jerarquía de valores y adaptación vertical con texto ampliado, mismos datos y bandera de confirmación.
4. `app/lib/widgets/parking_summary_card.dart`: tarjeta compacta con estado destacado y metadatos, mismos datos, condiciones y callback.

Nuevos:

5. `app/lib/widgets/estacionaya_components.dart`: marca Flutter, ficha informativa sin acciones ficticias, estado vacío y tarjeta de perfil exclusivamente visual.
6. `app/test/premium_interface_test.dart`: cuatro pruebas de regresión locales.
7. `docs/rediseno_premium_20261112.md`: auditoría y resultados.

Copias, logs y herramienta temporal de capturas se guardan únicamente bajo `tmp/premium_ui_20261112*`. No se añadieron dependencias ni recursos remotos.

## Límites y prueba manual

No se modificó intencionalmente ninguna funcionalidad. No se ejecutaron `flutter run`, `flutter install`, compilaciones Android, emuladores, ADB, instalaciones, despliegues, push ni actualizaciones externas. Las pruebas ejecutan widgets aislados en la computadora, no la aplicación en dispositivos.

La verificación en Android, GPS real, permisos, sesiones reales, teselas y conectividad con Supabase/cámaras queda a cargo del usuario. Desde PowerShell:

```powershell
cd C:\Users\Fercho\Documents\Aplicaciones-Mobiles\app
flutter run
```

Conservar los `--dart-define` habituales del entorno si son necesarios. No se cambió `config.dart` ni ningún archivo `.env`.
