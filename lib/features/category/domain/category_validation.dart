/// Pure validators for the category form, mirroring `AccountValidation`.
class CategoryValidation {
  const CategoryValidation._();

  static String? name(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Name erforderlich';
    if (trimmed.length > 60) return 'Name zu lang (max. 60 Zeichen)';
    return null;
  }
}
