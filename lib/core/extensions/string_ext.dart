extension StringExt on String {
  String get normalized => trim().toLowerCase();

  String removeAccents() {
    const src = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
    const dst = 'aaaaaaceeeeiiiinooooouuuuyy';
    // Ligatures expand to their letter pairs BEFORE the 1:1 map: the
    // recognizer emits "œuf" while stored answers say "oeuf", which
    // scored 0 twelve times in a row on one card (field log 2026-07-22).
    var result = replaceAll('œ', 'oe')
        .replaceAll('Œ', 'OE')
        .replaceAll('æ', 'ae')
        .replaceAll('Æ', 'AE');
    for (var i = 0; i < src.length; i++) {
      result = result.replaceAll(src[i], dst[i]);
    }
    return result;
  }

  bool get isKorean => runes.any((r) => r >= 0xAC00 && r <= 0xD7A3);
  bool get isFrench => !isKorean;
}
