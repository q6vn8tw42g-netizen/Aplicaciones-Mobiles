# EstacionaYa 3.0 · Experiencia del conductor

## Auditoría y decisiones

La versión anterior disponía de ciudad, mapa y panel deslizable. El control de cercanía filtraba plazas, pero el mapa no dibujaba la posición del usuario. Abrir la ficha desde la lista tampoco movía el mapa. El detalle dirigía siempre a Google Maps y habilitaba la acción al encontrar coordenadas, incluso con una plaza ocupada. El servicio de navegación ya contenía enlaces para Google Maps y Waze.

Se mantuvieron los filtros, la búsqueda, el catálogo secundario, el acceso de visitante, las sesiones y el mismo proveedor Realtime. La cabecera azul oscuro agrupa marca, zona y acceso al perfil. El mapa lleva su propio control de ubicación. El panel deslizable combina un resumen de tres celdas, fichas de plaza con estado e icono, tipo de vehículo cuando existe y señal de cámara. El color de cada celda distingue el total de las plazas libres y ocupadas. Las etiquetas siguen siendo legibles sin distinguir colores. Con texto ampliado, la cabecera y los conteos se reorganizan.

## Del mapa al destino

1. **Mi ubicación** consulta el GPS al tocarlo. Comprueba el servicio y el permiso de primer plano, solicita el permiso si corresponde y limita la espera a 15 segundos. Un punto azul representa la última posición consultada. Un segundo toque obtiene una posición nueva y vuelve a centrar el mapa. La app permite explorar con GPS desactivado o permiso denegado.
2. La consulta de cercanía usa el radio existente de 2 km, ordena por distancia y muestra metros o kilómetros aproximados en línea recta. El filtro se puede quitar. Antes del primer posicionamiento, la lista conserva el orden por nombre.
3. Seleccionar una ficha o un marcador abre el detalle del mismo identificador. Si existen coordenadas válidas, el mapa recupera el espacio visible y centra la cámara en ese punto. La agrupación de plazas con acceso compartido conserva sus coordenadas.
4. **Navegar** se habilita únicamente con destino válido, estado libre, lectura sincronizada y señal vigente de una cámara verificable. El selector escucha al proveedor mientras está abierto y vuelve a consultar la plaza antes de lanzar la aplicación externa. Un cambio de estado, pérdida de señal o eliminación del registro impide la salida a un destino que dejó de ser elegible.
5. En Android se dirige la intención de Google Maps al paquete de Google. La prueba en este teléfono mostró que el esquema genérico también lo reclaman otros navegadores. Waze usa su enlace de aplicación y ambos disponen de alternativa HTTPS. La elección no realiza ninguna escritura sobre la plaza.

Referencias de integración. [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started) · [Waze Deep Links](https://developers.google.com/waze/deeplinks)

## Archivos de la entrega

| Archivo | Cambio |
| --- | --- |
| `app/lib/screens/home_screen.dart` | Ubicación puntual, estados de permiso, filtro de cercanía, selección de plaza, enfoque del mapa, detalle reactivo, selector de navegación, Perfil y Ajustes. |
| `app/lib/widgets/mapa_espacios.dart` | Punto del usuario, solicitudes explícitas de centrado y presentación coherente del estado en pines y grupos. |
| `app/lib/widgets/parking_status.dart` | Nuevo componente de presentación compartido para texto, color e icono y para distinguir señal verificable. |
| `app/lib/widgets/camera_connection_badge.dart` | Uso del mismo criterio de cámaras verificables. |
| `app/lib/widgets/availability_strip.dart` | Conteos adaptables con etiquetas y superficies semánticas. |
| `app/lib/widgets/parking_summary_card.dart` | Ficha con transición de estado, disponibilidad principal y datos de monitoreo secundarios. |
| `app/lib/theme/estacionaya_theme.dart` | Indicador azul y contraste de iconos en la navegación inferior. |
| `app/lib/services/navigation_service.dart` | Apertura de Google Maps en Android y recuperación mediante enlace universal. |
| `app/android/app/src/main/kotlin/com/example/estacionaya/MainActivity.kt` | Canal nativo que valida el destino y dirige la intención al paquete de Google Maps. |
| `app/test/driver_navigation_test.dart` | Nuevas pruebas del GPS, controlador de mapa, selector, enlace de respaldo y pérdida de disponibilidad. |

El contenido de los modelos, el proveedor, los servicios de Supabase, los manifiestos de dependencias y las pantallas de autenticación coincide con el respaldo anterior a la iteración. Se reutilizaron los permisos móviles de primer plano y los paquetes instalados. El diff de FastAPI, Supabase y visión está vacío.

## Validación y evidencias

| Prueba | Resultado observado |
| --- | --- |
| Android 16, arranque en frío | La app abrió, cargó las teselas y mostró el panel y sus tres conteos. [Antes](../output/ux3/01_inicio_anterior.png) · [Después](../output/ux3/02_mapa.png) |
| Ubicación real | Con permiso previamente concedido y GPS activo, el usuario tocó Mi ubicación y apareció el punto azul. [Captura en Android](../output/ux3/03_mi_ubicacion.png) |
| Navegación inferior | Se observaron modo visitante y acción de acceso en Perfil, e información sobre ubicación en Ajustes. [Perfil](../output/ux3/04_perfil.png) · [Ajustes](../output/ux3/05_ajustes.png) |
| Datos disponibles | La consulta pública del visitante con el filtro productivo CAM-005 y ANT-001 a ANT-003 devolvió cero filas. La captura del mapa muestra ese estado vacío. |
| Navegadores instalados | Pruebas de intenciones desde Android con el punto de referencia del campus que ya utiliza el mapa. Waze abrió su actividad y la intención dirigida a Google Maps abrió MapsActivity. Luego se devolvió EstacionaYa al primer plano. |
| Pruebas de Flutter | 19 aprobadas. Se comprobaron el centro efectivo del controlador, ubicación denegada y concedida, GPS apagado, distancias, selección, coordenadas enviadas al canal Android, alternativas HTTPS y la desactivación del selector si se ocupa la plaza. |
| Análisis y compilación | Dependencias resueltas y APK debug compilado e instalado. El análisis devolvió código 1 por dos notas de estilo anteriores en api_service.dart, líneas 34 y 44. Cero errores y cero advertencias. |

La prueba de hardware verificó las pantallas con los datos disponibles para el visitante. El detalle y el modal se ejercitaron mediante pruebas de widgets con registros controlados. Quedan pendientes sus capturas con una plaza real elegible y el trayecto completo desde una actualización real de Supabase hasta la apertura externa. La prueba de intenciones utilizó el centro de referencia del mapa exclusivamente para validar la apertura de las aplicaciones.

## Estado local

Rama `codex/estacionaya-ui-ux`. Cambios sin confirmar y sin publicar. Se conservó el trabajo de las iteraciones anteriores. El respaldo previo de las fuentes y pruebas Flutter está en `tmp/antes_ux3_20261111_234104/`. El APK instalado se encuentra en `app/build/app/outputs/flutter-apk/app-debug.apk`.

