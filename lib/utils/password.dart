/// Misma regla que `Utils.checkPwd` de la web. Null = ok.
String? checkPwd(String? raw) {
  final str = raw?.trim() ?? '';
  if (str.isEmpty) return 'Contraseña vacía';
  if (str.length < 8) return 'Contraseña debe tener minimo 8 digitos';
  if (str.length > 20) return 'Contraseña no debe ser mayor a 20 digitos';
  if (!RegExp(r'\d').hasMatch(str)) {
    return 'Contraseña debe tener al menos un número';
  }
  if (!RegExp(r'[A-Z]').hasMatch(str)) {
    return 'La contraseña debe contener al menos una mayúscula';
  }
  if (!RegExp(r'[a-zA-Z]').hasMatch(str)) {
    return 'Contraseña debe tener al menos un letra';
  }
  if (!RegExp(r'[a-z]').hasMatch(str)) {
    return 'Contraseña debe tener al menos una letra minúscula';
  }
  if (!RegExp(r'[!#$%&()*+,\-./:;?@\[\\\]^_{}]').hasMatch(str)) {
    return 'Contraseña debe tener al menos un caracter especial de los siguientes !#\$%&()+/-.:?@_{}';
  }
  if (RegExp(r'[ =|;~*<>]').hasMatch(str) || str.contains('"') || str.contains("'")) {
    return 'La contraseña no permite los siguientes caracteres especiales = | ; " \' < >~ *';
  }
  return null;
}
