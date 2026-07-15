bool hasPdfSignature(List<int> bytes) {
  const signature = <int>[0x25, 0x50, 0x44, 0x46, 0x2d]; // %PDF-
  if (bytes.length < signature.length) return false;

  // ISO 32000 readers permit the header within the first 1024 bytes.
  final searchLimit = bytes.length < 1024 ? bytes.length : 1024;
  for (var offset = 0; offset <= searchLimit - signature.length; offset++) {
    var matches = true;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[offset + index] != signature[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}
