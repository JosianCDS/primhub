class ValidationManager {
  // Usamos un Set para búsquedas eficientes (O(1)) y evitar duplicados.
  static final Set<int> _hourValidationExceptions = {};

  /// Devuelve una copia inmutable del conjunto de excepciones.
  static Set<int> get hourValidationExceptions => Set.unmodifiable(_hourValidationExceptions);

  /// Reemplaza el conjunto de excepciones con uno nuevo.
  static void setExceptions(Set<int> bpIds) {
    _hourValidationExceptions.clear();
    _hourValidationExceptions.addAll(bpIds);
  }

  /// Verifica si un ID de tercero está en la lista de excepciones.
  static bool isExempt(int? bpId) {
    if (bpId == null) return false;
    return _hourValidationExceptions.contains(bpId);
  }
}
