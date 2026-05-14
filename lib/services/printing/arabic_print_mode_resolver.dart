enum ArabicPrintMode { text, image }

class ArabicPrintModeResolver {
  const ArabicPrintModeResolver();

  ArabicPrintMode resolve({
    required bool printerSupportsArabic,
    bool preferImageFallback = false,
  }) {
    if (preferImageFallback || !printerSupportsArabic) {
      return ArabicPrintMode.image;
    }
    return ArabicPrintMode.text;
  }
}
