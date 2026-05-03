/// string_extensions.dart
///
/// Extensión sobre String para convertir los valores de record_type
/// almacenados en la BD en nombres legibles para el usuario.
///
/// Los valores de record_type se almacenan en formato snake_case en
/// la tabla 'visits' de Supabase. Esta extensión los transforma en
/// etiquetas amigables para mostrar en el historial de visitas y
/// en los chips de selección de CheckInScreen.

extension StringHumanizer on String {

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: toFriendlyName
  // Convierte un valor de record_type en su nombre legible en español.
  //
  // Los casos explícitos del switch cubren los cinco tipos de consumo
  // definidos en el catálogo de medallas de TapeoGo. El caso default
  // actúa como fallback para cualquier valor no contemplado — limpia
  // los guiones bajos, pasa a minúsculas y capitaliza la primera letra.
  //
  // Ejemplo de uso en VisitCard:
  //   visit.recordType.toFriendlyName() → 'Solomillo al whisky'
  // ─────────────────────────────────────────────────────────────────────────
  String toFriendlyName() {
    switch (this) {
      case 'serranito':
        return 'Serranito';
      case 'solomillo_whisky':
        return 'Solomillo al whisky';
      case 'croquetas':
        return 'Croquetas';
      case 'cerveza':
        return 'Cerveza';
      case 'vino':
        return 'Vino';

      default:
        // Fallback para valores no contemplados en el switch.
        // Convierte 'otra_tapa' → 'Otra tapa' limpiando guiones bajos,
        // pasando a minúsculas y capitalizando la primera letra.
        final String cleaned = replaceAll('_', ' ').toLowerCase();
        if (cleaned.isEmpty) return '';
        return cleaned[0].toUpperCase() + cleaned.substring(1);
    }
  }
}