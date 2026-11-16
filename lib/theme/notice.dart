import 'package:flutter/material.dart';

/// Lo que dura un aviso común: lo justo para leer "listo" de reojo.
const Duration _noticeDuration = Duration(milliseconds: 1600);

/// Los avisos con botón duran más, porque hay que llegar a tocarlo.
const Duration _actionNoticeDuration = Duration(seconds: 4);

/// Aviso breve en el borde de abajo.
///
/// Todos los avisos de la app pasan por acá para que duren lo mismo y se vean
/// igual; la forma y el tamaño los pone `snackBarTheme` en el tema.
void showNotice(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) => showNoticeOn(ScaffoldMessenger.of(context), message, action: action);

/// Igual que [showNotice], para cuando el `ScaffoldMessenger` se capturó antes
/// de un `await` y ya no hay `BuildContext` que valga.
void showNoticeOn(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: action == null ? _noticeDuration : _actionNoticeDuration,
        action: action,
      ),
    );
}
