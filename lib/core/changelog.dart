/// Novedades de cada versión, para la pantalla "Qué hay de nuevo".
///
/// Al publicar una compilación nueva se agrega su entrada arriba de todo.
/// Si un build no trae nada para contar (un arreglo interno, un retoque del
/// CI) simplemente no se lista.
class ChangelogEntry {
  const ChangelogEntry({
    required this.build,
    required this.title,
    this.news = const [],
    this.fixes = const [],
  });

  final int build;

  /// Resumen corto de la versión.
  final String title;

  /// Cosas nuevas.
  final List<String> news;

  /// Arreglos.
  final List<String> fixes;
}

class Changelog {
  Changelog._();

  /// De la más nueva a la más vieja.
  static const List<ChangelogEntry> entries = [
    ChangelogEntry(
      build: 76,
      title: 'La canción ya no vuelve a todo volumen en medio de un video',
      fixes: [
        'Con un video con sonido, la música bajaba bien pero a los 6 segundos '
            'volvía a su volumen y se oía por encima del video. Ahora se '
            'queda baja hasta que el video suelta el audio.',
      ],
    ),
    ChangelogEntry(
      build: 75,
      title: 'Cada lista que reproducís es su propia cola',
      news: [
        'Las colas ahora se arman solas: tu lista, la biblioteca entera, un '
            'álbum, una selección... cada origen distinto es una cola aparte, '
            'y la anterior queda guardada en su canción y su segundo en vez '
            'de reemplazarse. Se cambia de una a otra desde la pantalla Cola.',
        'Si reproducís una lista que ya tenía cola, volvés a esa misma cola. '
            'Tocar otra canción de la lista que ya suena no crea nada nuevo.',
        'Cuando hay 12 colas, se saca la que hace más que no usás.',
      ],
    ),
    ChangelogEntry(
      build: 74,
      title: 'La música ya no queda baja después de un video',
      fixes: [
        'Si una app de video pedía el audio varias veces seguidas, la música '
            'podía quedar al 15 % para siempre aunque siguiera sonando. Ahora '
            'el volumen siempre vuelve cuando termina la interrupción.',
      ],
    ),
    ChangelogEntry(
      build: 72,
      title: 'Varias colas de reproducción',
      news: [
        'Podés tener varias colas, cada una independiente: con su canción, su '
            'segundo, su aleatorio y su bucle. En la pantalla Cola, tocá una '
            'para pasar a ella y sigue donde la dejaste. Mantené apretada una '
            'para cambiarle el nombre o borrarla.',
        'Al seleccionar canciones, "Reproducir en cola nueva" (en los tres '
            'puntos) las suena aparte sin perder la cola que tenías. "Nueva" '
            'arriba de la Cola crea una vacía.',
      ],
    ),
    ChangelogEntry(
      build: 71,
      title: 'Los botones del widget de atajos ya no se estiran',
      fixes: [
        'Con el widget de atajos a lo ancho de toda la pantalla, los cuatro '
            'botones se veían como óvalos. Ahora mantienen su forma redonda y '
            'se reparten el espacio.',
      ],
    ),
    ChangelogEntry(
      build: 70,
      title: 'El tic de enviar un mensaje ya no mueve la música',
      fixes: [
        'Los sonidos muy cortos (el tic de enviar un mensaje en WhatsApp) '
            'hacían bajar y subir el volumen por algo que ya había terminado. '
            'Ahora la música no se mueve si el sonido dura menos de un '
            'pestañeo.',
        'Con una notificación de verdad baja un poco menos que antes, y ya no '
            'hay nada que configurar: se fue esa opción de Ajustes.',
      ],
    ),
    ChangelogEntry(
      build: 69,
      title: 'La notificación ya no pausa la música',
      fixes: [
        'Tu teléfono avisa de una notificación con el mismo evento que de una '
            'llamada, así que la app pausaba la música unos segundos cada vez. '
            'Ahora baja el volumen y solo pausa si hay una llamada de verdad.',
        'Por lo mismo, el ajuste de cuánto bajar con una notificación '
            'empieza a funcionar: antes ese camino no se usaba nunca.',
      ],
    ),
    ChangelogEntry(
      build: 68,
      title: 'Fuera el fundido entre canciones',
      news: [
        'En Ajustes → Configuración avanzada hay un "Diagnóstico de audio": '
            'muestra qué le avisa Android a la app cuando la música se baja o '
            'se pausa sola. Sirve para saber si algo lo hizo la app o el '
            'sistema.',
      ],
      fixes: [
        'Se quitó el fundido entre canciones. Era la causa de que el audio se '
            'trabara: calculaba el volumen a partir de la posición de la '
            'canción, y si ese cálculo quedaba clavado (al bloquear el '
            'teléfono, por ejemplo) la música seguía corriendo sin que se '
            'oyera nada.',
      ],
    ),
    ChangelogEntry(
      build: 67,
      title: 'Reordenar sin mantener apretado',
      fixes: [
        'Para mover una canción en la cola o en una lista ya no hay que '
            'mantener apretado: se arrastra desde las rayitas y arranca al '
            'toque. La zona del dedo sobre las rayitas también es más grande.',
      ],
    ),
    ChangelogEntry(
      build: 66,
      title: 'Play desde el auricular con la app cerrada',
      fixes: [
        'Si el sistema despierta la app por un botón del auricular, el play '
            'ahora retoma lo último que escuchabas. Antes podía llegar antes '
            'de que la cola estuviera cargada y no sonaba nada.',
      ],
    ),
    ChangelogEntry(
      build: 65,
      title: 'La notificación ya no hace un pozo en la música',
      news: [
        'La música arranca sola al conectar auriculares o un parlante, y '
            'sigue lo último que estabas escuchando aunque hayas cerrado la '
            'app. Se puede apagar en Ajustes → Sonido.',
      ],
      fixes: [
        'Cuando entra una notificación, el volumen ahora baja y vuelve de a '
            'poco en vez de pegar un salto. Y baja menos: 20 % en lugar de '
            '40 %. Si preferís que no baje nada, está la opción "No bajar".',
      ],
    ),
    ChangelogEntry(
      build: 64,
      title: 'Cambiar a aleatorio ya no corta la música',
      fixes: [
        'Activar o desactivar el aleatorio callaba la música un segundo: se '
            'rearmaba la cola entera y la canción se recargaba. Ahora se '
            'reordena alrededor de la que suena, sin tocarla.',
        'El reproductor ya no salta de pista si el archivo está cargando '
            'cerca del final: antes podía confundir una carga lenta con un '
            'cuelgue y pasar a la siguiente sola.',
      ],
    ),
    ChangelogEntry(
      build: 63,
      title: 'Avisos más chicos y más cortos',
      fixes: [
        'Los carteles de confirmación ("se agregó a la lista") ocupaban media '
            'pantalla y tardaban en irse. Ahora son una pastilla chica que '
            'dura un segundo y medio, y los textos son más cortos.',
      ],
    ),
    ChangelogEntry(
      build: 62,
      title: 'Vos elegís cuánto baja la música con una notificación',
      news: [
        'En Ajustes → Sonido: "Bajar el volumen con notificaciones", de 0 a '
            '100 %. Por defecto baja un 40 %, así la notificación se escucha '
            'encima y la música no desaparece.',
      ],
      fixes: [
        'Antes el descuento lo elegía Android por su cuenta y en algunos '
            'teléfonos dejaba la música inaudible. Ahora lo decide la app.',
      ],
    ),
    ChangelogEntry(
      build: 61,
      title: 'Vuelve donde lo dejaste, y los auriculares se reconocen solos',
      fixes: [
        'El ■ de la notificación borraba la sesión antes de cerrar la app: al '
            'volver a entrar no estaba la última canción, ni el aleatorio, ni '
            'el bucle. Ahora se guarda en qué canción y en qué segundo quedó.',
        'El aleatorio y el bucle vuelven como los dejaste aunque no haya cola '
            'para retomar.',
        'La inversión de botones no se activaba al conectar los auriculares '
            'con la app ya abierta: Android no siempre avisa. Ahora la salida '
            'se vuelve a leer en cada botonazo y al volver a la app.',
        'Una notificación dejaba la música inaudible: Android ya baja el '
            'volumen solo y la app lo bajaba otra vez encima.',
      ],
    ),
    ChangelogEntry(
      build: 60,
      title: 'Se terminaron los tirones al abrir el teclado',
      fixes: [
        'Abrir el teclado o recibir una notificación le saca el foco a la '
            'app un instante, y eso disparaba una revisión completa de las '
            'carpetas como si hubieras vuelto de otra app. Ahora solo se '
            'revisa cuando la app estuvo de verdad en segundo plano.',
        'Revisar qué archivos cambiaron bloqueaba la app: se consultaba el '
            'disco de a una canción por vez y sin soltar el hilo principal.',
      ],
    ),
    ChangelogEntry(
      build: 59,
      title: 'La música ya no se corta con las notificaciones',
      fixes: [
        'Cuando entraba una notificación, la música se cortaba por completo '
            'unos segundos. Ahora baja el volumen un momento y sigue.',
        'Escribir en el buscador trababa el audio un instante en bibliotecas '
            'grandes: la búsqueda ahora espera a que sueltes el teclado.',
      ],
    ),
    ChangelogEntry(
      build: 57,
      title: 'El repositorio pasó a llamarse Resonar',
      fixes: [
        'El aviso de versión nueva apuntaba al nombre viejo del repositorio.',
      ],
    ),
    ChangelogEntry(
      build: 54,
      title: 'El botón + ya no tapa nada',
      fixes: [
        'En Listas había dos botones flotantes que quedaban encima del menú '
            'de las listas. Ahora es uno solo y adentro están crear e '
            'importar.',
      ],
    ),
    ChangelogEntry(
      build: 53,
      title: 'El aleatorio y el bucle se quedan puestos',
      news: [
        'Al volver a entrar, el aleatorio y el bucle siguen como los '
            'dejaste. Antes arrancaban siempre apagados.',
      ],
    ),
    ChangelogEntry(
      build: 51,
      title: 'Invertir botones solo en ciertos auriculares',
      news: [
        'La inversión de siguiente y anterior se elige por dispositivo: '
            'se aplica a los auriculares que la necesitan y el parlante '
            'bluetooth sigue funcionando normal.',
      ],
    ),
    ChangelogEntry(
      build: 50,
      title: 'La biblioteca se actualiza sola',
      news: [
        'Las canciones nuevas aparecen sin tener que recargar nada: la app '
            'revisa al abrirla, al volver de otra app y cada tanto mientras '
            'la usás.',
      ],
    ),
    ChangelogEntry(
      build: 48,
      title: 'Ajustes más ordenados',
      news: [
        'Las carpetas de música y las ignoradas tienen su propia pantalla, '
            'con pestañas y el nombre de cada carpeta a la vista.',
        'En Sonido quedan a mano las opciones de siempre; el resto está en '
            '"Configuración avanzada".',
      ],
    ),
    ChangelogEntry(
      build: 47,
      title: 'Novedades y avisos más seguidos',
      news: [
        'Esta pantalla: tocá la versión en Ajustes para ver qué cambió.',
        'Al instalar una versión nueva, las novedades aparecen solas.',
      ],
      fixes: [
        'El aviso de actualización se fija casi en cada arranque; antes '
            'esperaba seis horas y te enterabas tarde.',
      ],
    ),
    ChangelogEntry(
      build: 44,
      title: 'Volumen y versión',
      news: [
        'La música se pausa si bajás el volumen del todo.',
        'Al darle a reproducir con el volumen en cero, sube una rayita.',
        'Apartado "Acerca de" en Ajustes con la versión instalada.',
      ],
    ),
    ChangelogEntry(
      build: 43,
      title: 'Ecualizador propio',
      news: [
        'Ecualizador adentro de la app, con bandas, curvas listas '
            '(Graves, Voces, Agudos…) y refuerzo de volumen.',
      ],
      fixes: [
        'Antes abría el del sistema y hay teléfonos que no traen ninguno.',
      ],
    ),
    ChangelogEntry(
      build: 42,
      title: 'Botón de anterior',
      news: [
        'Pasados 5 segundos, "anterior" reinicia la canción; dentro de los '
            'primeros 5, salta a la pista de antes.',
      ],
    ),
    ChangelogEntry(
      build: 41,
      title: 'Auriculares y notificación',
      news: [
        'Ajuste para invertir siguiente y anterior de los auriculares.',
        'El ■ de la notificación ahora también cierra la app.',
      ],
    ),
    ChangelogEntry(
      build: 39,
      title: 'Aleatorio que no se vuelve loco',
      fixes: [
        'El aleatorio mezcla la cola una sola vez y respeta ese orden. '
            'Antes elegía al azar en cada salto y había canciones que no '
            'sonaban nunca.',
        'La cola que ves es la que va a sonar, y la podés reordenar.',
      ],
    ),
    ChangelogEntry(
      build: 38,
      title: 'Selección más clara',
      fixes: [
        'Al elegir canciones, la tilde va a la derecha y la carátula queda '
            'a la vista.',
      ],
    ),
    ChangelogEntry(
      build: 37,
      title: 'Listas con opciones',
      news: [
        'Mantené apretada una canción de una lista para elegir varias.',
        'Menú por canción: reproducir a continuación, a la cola, a otra '
            'lista, favorita, género, mover al principio o al final, quitar.',
      ],
    ),
    ChangelogEntry(
      build: 35,
      title: 'Widgets presentables',
      fixes: [
        'La carátula del widget salía como un cuadrado de color sólido.',
        'Botones al costado del texto: entra bien en dos celdas.',
      ],
    ),
    ChangelogEntry(
      build: 34,
      title: 'Widgets a tu color',
      fixes: [
        'Los widgets ignoraban el color de acento y quedaban naranjas.',
        'Vista previa de verdad en el selector de widgets de Android.',
      ],
    ),
    ChangelogEntry(
      build: 33,
      title: 'Descargas que avisan',
      fixes: [
        'La descarga de actualizaciones se quedaba colgada sin decir nada. '
            'Ahora muestra los MB, el motivo si falla, y deja reintentar.',
      ],
    ),
    ChangelogEntry(
      build: 32,
      title: 'Widgets a gusto',
      news: [
        'Fondo del widget oscuro, claro, de acento o con la carátula, con '
            'la opacidad que quieras.',
      ],
      fixes: [
        'Si una canción se trababa en el último segundo, ahora pasa sola.',
      ],
    ),
    ChangelogEntry(
      build: 30,
      title: 'Widgets de pantalla de inicio',
      news: [
        'Widget con carátula y controles, y otro con atajos: seguir, todo '
            'al azar, favoritas y buscar.',
      ],
    ),
    ChangelogEntry(
      build: 29,
      title: 'Arreglo del cierre al abrir',
      fixes: [
        'La app se cerraba al abrirla por una librería de carátulas que '
            'pedía permisos de fotos y videos que no hacían falta.',
      ],
    ),
    ChangelogEntry(
      build: 25,
      title: 'Temas, Sonando y resumen',
      news: [
        'Temas claro, oscuro y AMOLED, con ocho colores de acento.',
        '"Sonando" toma el color de la carátula; se desliza para cambiar de '
            'canción y la letra se abre a pantalla completa.',
        'Listas automáticas: Más escuchadas, Agregadas recientemente y '
            'Redescubrí, más "Tu resumen" de escucha.',
        'Fundido entre canciones.',
      ],
    ),
    ChangelogEntry(
      build: 19,
      title: 'Listas y actualizaciones',
      news: [
        'Cambiarle el nombre a una lista.',
        'Las actualizaciones se descargan e instalan desde la app.',
      ],
    ),
  ];

  static int get latestBuild => entries.isEmpty ? 0 : entries.first.build;
}
