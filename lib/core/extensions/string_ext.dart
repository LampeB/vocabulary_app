extension StringExt on String {
  String get normalized => trim().toLowerCase();

  String removeAccents() {
    const src = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
    const dst = 'aaaaaaceeeeiiiinooooouuuuyy';
    var result = this;
    for (var i = 0; i < src.length; i++) {
      result = result.replaceAll(src[i], dst[i]);
    }
    return result;
  }

  bool get isKorean => runes.any((r) => r >= 0xAC00 && r <= 0xD7A3);
  bool get isFrench => !isKorean;
}
