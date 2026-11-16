# Historial de cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

Las versiones publicadas se numeran por compilación (`build-N`), que es lo que
aparece en los [releases](https://github.com/B3njaminGC/Resonar/releases)
y en *Ajustes → Qué hay de nuevo* dentro de la app. Entre paréntesis va la
versión de la app.

## [No publicado]

### Corregido (reproducción)
- `toggleShuffle` llamaba a `setPlaylistAndPlay`, que rehace la
  `ConcatenatingAudioSource` con `setAudioSource` y obliga a recargar la pista
  actual: ese era el segundo de silencio. Ahora `_reorderInPlace` saca lo que
  está antes y después de la pista que suena y lo reinserta en el orden nuevo
  (cuatro operaciones, no importa el tamaño de la cola); la pista actual no se
  toca.
- El vigilante de fin de pista ya no cuenta como "trabado" una lectura en la
  que el reproductor está cargando: `buffering` cerca del final podía
  disparar un `seekToNext` y saltear una canción sana. La condición vive en
  `looksStuckAtEnd`, con pruebas.
- `startFade`, `startEndWatchdog` y `startVolumeWatch` son idempotentes: dos
  llamadas dejaban dos temporizadores y dos oyentes sobre el mismo
  reproductor.

### Cambiado (avisos)
- Los avisos de confirmación pasan a ser una pastilla flotante chica (13 px,
  esquinas redondeadas) de 1,6 segundos, en vez de la barra ancha de Material
  de 4 segundos. El estilo vive en `snackBarTheme` y la duración en
  `showNotice`/`showNoticeOn` (`lib/theme/notice.dart`), por donde pasan ahora
  los 22 avisos de la app. Los que tienen botón siguen durando 4 segundos,
  porque hay que llegar a tocarlo.
- Textos de confirmación más cortos, y "añadir" pasa a "agregar" para
  emparejar con el resto de la app.

### Añadido
- *Ajustes → Sonido → Bajar el volumen con notificaciones*: cuánto baja la
  música mientras suena una notificación (0, 20, 40, 60 o 100 %). Por defecto,
  40 %.

### Cambiado
- `androidWillPauseWhenDucked` pasa a **true** y la app maneja las
  interrupciones (`handleInterruptions: false` en el reproductor). En false,
  la documentación de Android es explícita: el sistema baja el volumen por su
  cuenta y *no notifica a la app*, así que el descuento lo decidía el teléfono
  y en algunos modelos dejaba la música inaudible. En true ese automatismo se
  desactiva, Android avisa y el volumen lo elegimos nosotros. El precio es
  tener que pausar y reanudar a mano en una interrupción real (una llamada),
  que es lo que hace `_onInterruption`.

## [build-61] - 2026-11-15

### Corregido
- El botón ■ de la notificación llamaba a `clearQueue()`, que además de vaciar
  la cola guardaba una sesión vacía en disco. Como el ■ cierra la app, al
  volver a entrar no había nada que retomar: ni canción, ni aleatorio, ni
  bucle. Ahora el ■ guarda la posición y no borra la sesión.
- El aleatorio y el bucle se restauran antes de buscar la cola guardada, así
  que vuelven como estaban incluso sin cola.
- `AudioOutputs` solo leía las salidas al iniciar y confiaba en
  `devicesStream`, que en Android no siempre avisa cuando se conectan unos
  auriculares bluetooth. Se agregó `refresh()`, que corre en cada botón de
  auricular y al volver a la app.
- El agachado de volumen propio se multiplicaba con el de Android y dejaba la
  música inaudible ante una notificación; ahora lo hace solo el sistema.

## [build-60] - 2026-11-14

### Corregido
- Abrir el teclado o recibir una notificación le quita el foco a la app sin
  mandarla a segundo plano, y eso disparaba una revisión completa de las
  carpetas. Ahora se distingue perder el foco de volver de otra app.
- La revisión de qué archivos cambiaron usaba `FileStat.statSync` una vez por
  canción en el isolate principal; en el almacenamiento de Android (FUSE) eso
  congelaba la app varios segundos. Ahora va asíncrona y en tandas de 64.

## [build-59] - 2026-11-14

### Corregido
- Al entrar una notificación, la música se cortaba del todo hasta que el
  sonido terminaba. La sesión de audio ahora pide explícitamente que Android
  baje el volumen (*ducking*) en vez de avisar para pausar.
- Escribir en el buscador podía trabar el audio un instante: el texto
  buscable de cada canción se arma una vez al cargar la biblioteca y el
  filtrado espera a que el teclado se quede quieto.

## [build-57] - 2026-11-13

### Corregido
- El aviso de versión nueva apuntaba al nombre viejo del repositorio.

## [build-55] - 2026-11-11 (1.3.0)

### Corregido
- En Listas había dos botones flotantes que tapaban el menú de cada lista.
  Ahora es uno solo y adentro están crear e importar.
- La compilación fallaba por el análisis de Android (lint) de una librería de
  terceros; se desactivó porque no afecta al APK.

## [build-53] - 2026-11-11

### Añadido
- El aleatorio y el bucle se mantienen al cerrar y volver a abrir la app.

## [build-52] - 2026-11-09

### Cambiado
- La inversión de los botones de siguiente y anterior se configura por
  dispositivo: se aplica solo a los auriculares que la necesitan.

## [build-50] - 2026-11-09

### Corregido
- Al abrir la app desde cero no se buscaban canciones nuevas hasta pasados dos
  minutos. Ahora se busca al arrancar.

### Cambiado
- La detección de canciones nuevas dejó de ser opcional: siempre está activa.

## [build-49] - 2026-11-09

### Añadido
- La biblioteca se actualiza sola al volver de otra app y cada dos minutos
  mientras Resonar está abierta.

## [build-48] - 2026-11-07

### Cambiado
- Ajustes reorganizado: en Sonido quedan las opciones de siempre y el resto en
  "Configuración avanzada".
- Las carpetas incluidas e ignoradas pasaron a una pantalla propia con pestañas.

## [build-47] - 2026-11-07

### Añadido
- Pantalla "Qué hay de nuevo" con lo que trajo cada versión, que además
  aparece sola después de actualizar.

### Corregido
- El aviso de actualización solo consultaba una vez cada seis horas.

## [build-44] - 2026-11-07

### Añadido
- La música se pausa al bajar el volumen del teléfono a cero.
- Al reproducir con el volumen en cero, se sube un paso.
- Apartado "Acerca de" con la versión instalada.

## [build-43] - 2026-11-07

### Añadido
- Ecualizador propio de la app: bandas, curvas listas y refuerzo de volumen.

### Corregido
- El ecualizador anterior dependía de que el teléfono trajera uno del sistema,
  y hay modelos que no.

## [build-42] - 2026-11-07

### Cambiado
- El botón de anterior reinicia la canción salvo en los primeros 5 segundos.

## [build-41] - 2026-11-07

### Añadido
- Opción para invertir los botones de siguiente y anterior de los auriculares.
- El botón de detener de la notificación también cierra la app.

## [build-39] - 2026-11-07

### Corregido
- El modo aleatorio elegía una pista al azar en cada salto y había canciones
  que no sonaban nunca. Ahora la cola se mezcla una sola vez y ese orden se
  respeta.

## [build-38] - 2026-11-07

### Cambiado
- Al seleccionar canciones, la marca de selección va a la derecha y la carátula
  queda visible.

## [build-37] - 2026-11-07

### Añadido
- Selección múltiple dentro de una lista y menú de opciones por canción.

## [build-35] - 2026-11-07

### Corregido
- La carátula del widget aparecía como un cuadrado de color sólido.
- El widget se rediseñó para entrar en dos celdas de alto.

## [build-34] - 2026-11-06

### Corregido
- Los widgets ignoraban el color de acento elegido.
- Vista previa real en el selector de widgets de Android.
- El ecualizador del sistema llamaba a un canal nativo que no existía.

## [build-33] - 2026-11-06

### Corregido
- La descarga de actualizaciones podía quedarse colgada sin avisar. Ahora
  muestra el progreso, explica el motivo del fallo y permite reintentar.

## [build-32] - 2026-11-05 (1.3.0)

### Añadido
- Fondo de los widgets configurable: oscuro, claro, de acento o con la carátula,
  con opacidad regulable.

### Corregido
- Si una canción se trababa en el último segundo, ahora pasa sola a la
  siguiente.

## [build-30] - 2026-11-05

### Añadido
- Widgets de pantalla de inicio: uno con carátula y controles, otro con atajos.

## [build-29] - 2026-11-05

### Corregido
- La app se cerraba al abrirla por una librería de carátulas que exigía
  permisos de fotos y videos innecesarios. Se quitó la librería y los permisos.

## [build-25] - 2026-11-04 (1.2.0)

### Añadido
- Temas claro, oscuro y AMOLED con ocho colores de acento.
- "Sonando" toma el color de la carátula, con gestos y letra a pantalla
  completa.
- Listas automáticas (Más escuchadas, Agregadas recientemente, Redescubrí) y
  pantalla "Tu resumen".
- Fundido entre canciones.

## [build-19] - 2026-11-03

### Añadido
- Cambiar el nombre de una lista de reproducción.
- Las actualizaciones se descargan e instalan desde la propia app.

## [build-17] - 2026-11-03

### Cambiado
- Repositorio ordenado: README más corto, licencia MIT y guía de desarrollo
  aparte.

## [build-16] - 2026-11-03

### Añadido
- Notificación del reproductor con carátula, progreso, favorita y controles.
- Selección múltiple de canciones en la biblioteca.
- Importar y exportar listas en formato M3U.
- Guardar la cola actual como lista.
- Géneros automáticos por etiqueta y propios con código corto.
- Aviso de versión nueva desde GitHub.

### Corregido
- Títulos ilegibles en archivos descargados con Snaptube.

## [build-9] - 2026-11-03

### Cambiado
- La app pasó a llamarse **Resonar**.

## [build-1] - 2026-10-31 (1.1.0)

### Añadido
- Primera versión publicada: biblioteca local, favoritas, listas, artistas,
  álbumes y orígenes de descarga, con compilación automática del APK.
