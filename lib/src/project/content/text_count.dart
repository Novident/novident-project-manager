import 'package:novident_editor_document/novident_editor_document.dart';

/// Word/character counters, mirroring the editor's own `word_counter_service`.
///
/// - **words** = every run of non-whitespace (`\S+`) in the document plain text
///   (language-agnostic: handles accents and any script).
/// - **characters** = Unicode code points (runes) of the plain text.
/// - **charactersNoSpaces** = runes of the plain text without whitespace.
class TextCount {
  /// Word count.
  final int words;

  /// Character count (Unicode code points, whitespace included).
  final int characters;

  /// Character count without whitespace.
  final int charactersNoSpaces;

  /// Builds a counter result.
  const TextCount({
    required this.words,
    required this.characters,
    required this.charactersNoSpaces,
  });

  /// All counters at zero.
  static const TextCount zero = TextCount(
    words: 0,
    characters: 0,
    charactersNoSpaces: 0,
  );

  /// Sums two counter results field by field.
  TextCount operator +(TextCount other) => TextCount(
        words: words + other.words,
        characters: characters + other.characters,
        charactersNoSpaces: charactersNoSpaces + other.charactersNoSpaces,
      );
}

/// Counts the whole editor [Document] (all blocks, recursively).
TextCount countEditorDocument(Document document) {
  final StringBuffer buffer = StringBuffer();
  _appendPlainText(document.root, buffer);
  return countText(buffer.toString());
}

/// Counts [text] the same way the editor's counter does.
TextCount countText(String text) {
  final int words = _wordRegex.allMatches(text).length;
  int characters = 0;
  int charactersNoSpaces = 0;
  for (final int rune in text.runes) {
    characters++;
    if (!_isWhitespaceRune(rune)) {
      charactersNoSpaces++;
    }
  }
  return TextCount(
    words: words,
    characters: characters,
    charactersNoSpaces: charactersNoSpaces,
  );
}

/// Every non-whitespace run counts as one word (matches the editor service).
final RegExp _wordRegex = RegExp(r'\S+');

/// Whether [rune] is a whitespace character.
bool _isWhitespaceRune(int rune) {
  final String character = String.fromCharCode(rune);
  return character.trim().isEmpty;
}

/// Appends the plain text of [node] and all its descendants to [buffer].
void _appendPlainText(Node node, StringBuffer buffer) {
  final Delta? delta = node.delta;
  if (delta != null) {
    buffer.write(delta.toPlainText());
  }
  for (final Node child in node.children) {
    _appendPlainText(child, buffer);
  }
}
