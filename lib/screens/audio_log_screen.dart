import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/audio_log.dart';
import '../theme/accent.dart';
import '../theme/notice.dart';

/// Muestra los últimos eventos de audio para poder mandar una captura.
///
/// Sirve para contestar una pregunta que de otro modo es pura adivinanza:
/// cuando la música se baja sola, ¿lo hizo la app o el sistema? Si entra una
/// notificación y acá no aparece nada, Android no avisó y entonces no hay
/// ajuste de la app que pueda cambiarlo.
class AudioLogScreen extends StatelessWidget {
  const AudioLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico de audio'),
        actions: [
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy_all),
            onPressed: () {
              final text = AudioLog.entries.value.reversed.join('\n');
              if (text.isEmpty) {
                showNotice(context, 'No hay nada para copiar');
                return;
              }
              Clipboard.setData(ClipboardData(text: text));
              showNotice(context, 'Registro copiado');
            },
          ),
          IconButton(
            tooltip: 'Limpiar',
            icon: const Icon(Icons.delete_outline),
            onPressed: AudioLog.clear,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Qué hacer: tocá "Limpiar", poné música, provocá lo que querés '
              'revisar (que entre una notificación, por ejemplo) y volvé acá.\n\n'
              'Si no aparece ninguna línea nueva, significa que Android no le '
              'avisó nada a la app: lo que pasó lo hizo el sistema y no se '
              'puede cambiar desde acá.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade700,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: AudioLog.entries,
              builder: (context, entries, _) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Todavía no pasó nada.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      entries[index],
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: index == 0 ? context.accent : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
