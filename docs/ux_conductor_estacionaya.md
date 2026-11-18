# EstacionaYa · Interfaz del conductor

Segunda iteración de diseño en Flutter. Rama local `codex/estacionaya-ui-ux`.

## Inicio y disponibilidad

La versión anterior abría el catálogo de calles. En la captura del teléfono, el nombre de la ciudad, el recuento de tramos, el buscador y el selector de vista ocupaban el espacio previo a la primera plaza. La acción de ubicación estaba situada debajo del panel móvil.

La nueva portada abre el mapa de plazas monitoreadas. La cabecera reúne marca, ciudad y perfil. En teléfonos estrechos con texto ampliado, la ciudad pasa a una segunda fila. El panel móvil abre al 36 % del alto disponible bajo la cabecera y puede expandirse hasta el 95 %. En pantallas de al menos 900 píxeles lógicos la lista ocupa una columna junto al mapa. Búsqueda y cercanía están al alcance desde la cabecera del panel.

Los tres conteos describen la misma selección del proveedor que la lista, incluidos los filtros de ciudad, búsqueda y cercanía. El total incluye los espacios sin servicio y los estados adicionales. Libres y ocupados cuentan únicamente registros con el estado correspondiente y el indicador de visión en línea que entrega el proveedor. Por ello, ambos valores pueden sumar menos que el total. Durante la carga o un error de sincronización aparecen guiones. Una consulta válida sin registros muestra ceros y un mensaje de zona vacía.

El mapa utiliza los puntos georreferenciados y el agrupamiento existente. En la apertura de la vista monitoreada puede centrar la cámara del mapa en la primera plaza visible con destino válido. La posición de una plaza se conserva incluso cuando varias comparten acceso. El pin individual señala su coordenada con la punta. La lista mantiene los espacios sin GPS que admite el filtro original. Su detalle informa que el destino está pendiente.

Cada tarjeta combina nombre, estado con icono y texto, señal de monitoreo y datos disponibles de distancia o vehículo. El detalle escucha al mismo proveedor mientras permanece abierto. Si la plaza se elimina, desaparece la acción de navegación. El grupo de Antisana también refleja cambios en sus miembros. La marca temporal describe la última actualización del estado. El distintivo de conexión utiliza la evidencia de señal ya evaluada por el proveedor para CAM-001 y CAM-005. En carga, error o cámara sin evidencia verificable aparece «Conexión no verificada».

## Navegación y sistema visual

Mapa, Perfil y Ajustes conservan los índices originales. Perfil muestra el correo de la sesión existente o el modo visitante y su acción de acceso. Ajustes concentra la descripción de la app, la explicación de la señal y el acceso secundario al catálogo. Desde el catálogo se puede regresar a espacios monitoreados. Las herramientas de dibujo y exportación se conservan para desarrollo con `--dart-define=EDITOR_TRAMOS=true` en modo debug.

El azul de marca se conserva. El resumen utiliza azul noche `#142C53`, números de alto contraste y etiquetas de texto. La ficha usa verde o rojo para los estados libre y ocupado, ámbar para reservado y gris para indisponibilidad. La navegación inferior mide 64 píxeles lógicos. Las fichas, los pines y las secciones secundarias respetan la preferencia de movimiento reducido.

## Archivos de esta iteración

| Archivo en app | Intervención |
| --- | --- |
| lib/screens/home_screen.dart | Inicio, ciudad, panel, búsqueda, navegación secundaria, detalle actualizado, Perfil y Ajustes. |
| lib/widgets/availability_strip.dart | Resumen adaptable de conteos y estado de datos pendientes. |
| lib/widgets/parking_summary_card.dart | Ficha compacta de plaza y acceso al detalle. |
| lib/widgets/camera_connection_badge.dart | Explicación de la señal en lenguaje de usuario. |
| lib/widgets/mapa_espacios.dart | Pines, grupos, atribución visible sobre el mapa y detalle de acceso compartido. |
| lib/theme/estacionaya_theme.dart | Superficie azul noche, jerarquía de títulos y barra inferior. |
| test/monitored_home_test.dart | Pruebas con flujos controlados de espacios y señal, cambio de ciudad y pantalla estrecha. |
| test/ui_contract_test.dart | Galería de evidencia reproducible con datos de prueba. |

## Verificación

- **Android 16 físico.** Se actualizó la instalación existente con el APK de depuración y se abrió la app en frío. Se verificaron las teselas del mapa, el estado vacío de Tulcán, el panel deslizable y las pantallas de Perfil y Ajustes. El usuario seleccionó esas dos pestañas en el teléfono.
- **Datos reales.** Una lectura con la configuración pública del cliente y el filtro CAM-005 / ANT-001 a ANT-003 devolvió cero filas. Es el resultado visible para un visitante con esa consulta. No determina cuántas filas existen en toda la base. Queda pendiente la prueba física de una plaza real que cambie de ocupación en directo y la apertura de la navegación desde ella.
- **Pruebas automatizadas.** Las 14 pruebas Flutter pasaron. La suite comprueba formularios de acceso, carga y pérdida de señal, textos grandes, teclado, reducción de movimiento, navegación al detalle, conteos tras cambios, desaparición del grupo y selector de ciudad. Las pruebas de widgets utilizan flujos controlados. Las teselas externas se comprobaron en el teléfono. No se inició sesión con una cuenta real.
- **Herramientas.** `flutter pub get` y la compilación del APK terminaron correctamente. El análisis estático terminó con código 1 por dos observaciones informativas anteriores de estilo en `lib/services/api_service.dart`, líneas 34 y 44. Cero errores y cero advertencias.
- **Git.** Se conservó la rama local y el trabajo sigue sin confirmar. El punto de recuperación previo está en `tmp/ui_conductor_20261111_231155/`, con fuentes móviles, pruebas, manifiestos y estado de Git. La comparación con esa copia confirma que modelos, servicios, proveedor, configuración y manifiestos conservan su contenido. Los cambios previos en Login, Splash, EspacioCard y los manifiestos ya estaban presentes antes de esta iteración. Backend, visión y Supabase no registran cambios en el diff.

## Evidencias

| Evidencia | Origen |
| --- | --- |
| [Vista anterior](../output/ux_conductor/01_antes.png) | Android físico, instalación anterior con el panel extendido. |
| [Inicio actual](../output/ux_conductor/02_inicio.png) | Android físico, tras abrir la compilación definitiva. |
| [Perfil](../output/ux_conductor/03_perfil.png) · [Ajustes](../output/ux_conductor/04_ajustes.png) | Android físico en modo visitante. |
| [Panel expandido](../output/ux_conductor/panel_expandido.png) | Android físico con el aviso del servicio de ubicación desactivado. |
| [Tarjetas con datos de prueba](../output/ux_conductor/fichas_datos_de_prueba.png) | Render de los widgets Flutter con dos registros de prueba, identificados en la propia imagen. |

