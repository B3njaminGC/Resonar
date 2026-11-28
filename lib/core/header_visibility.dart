/// Si la barra del título tiene que mostrarse (`true`), esconderse (`false`)
/// o quedarse como está (`null`) después de un desplazamiento de [delta]
/// (positivo = la lista baja).
///
/// Una lista corta nunca esconde la barra: al esconderla la lista pasaría a
/// entrar entera, perdería el scroll y la barra empezaría a parpadear.
bool? headerVisibilityFor({
  required double pixels,
  required double maxScrollExtent,
  required double delta,
  bool alwaysVisible = false,
}) {
  if (alwaysVisible || pixels <= 0) return true;
  if (pixels >= maxScrollExtent) return null;
  if (delta > 2 && maxScrollExtent > 240) return false;
  if (delta < -2) return true;
  return null;
}
