final RegExp _slugPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

bool isValidSlug(String value) {
  if (value.isEmpty) return false;
  return _slugPattern.hasMatch(value);
}
