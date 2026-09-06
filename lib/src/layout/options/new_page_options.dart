import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Mutable holder for a value (used so counters can be shared and updated).
class ObjectValue<T> {
  /// The wrapped value.
  T value;

  /// Wraps [value].
  ObjectValue({required this.value});
}

/// Page-break behavior of a layout: how many empty lines are written before
/// the content and how many leading characters are uppercased after the break.
@immutable
class NewPageOptions extends Equatable {
  /// Number of new lines written before the content (based on the value
  /// passed at construction).
  final ObjectValue<int> newLinesCount;

  /// How many leading characters are converted to uppercase after the page
  /// break.
  ///
  /// Example:
  /// ```dart
  /// NewPageOptions(
  ///   newLinesCount: 0,
  ///   charactersToUpperCase: 2,
  /// );
  /// ```
  ///
  /// Transforms this content:
  /// ```console
  /// "first word"
  /// ```
  ///
  /// into:
  /// ```console
  /// "FIrst word"
  /// ```
  ///
  /// This value only applies right after a page break, and must be between 0
  /// and 10.
  final ObjectValue<int> charactersToUpperCase;

  /// Builds the page-break options; [newLinesCount] must be non-negative.
  NewPageOptions({
    required int newLinesCount,
    required int charactersToUpperCase,
  })  : newLinesCount = ObjectValue(value: newLinesCount),
        charactersToUpperCase = ObjectValue(value: charactersToUpperCase),
        assert(
          charactersToUpperCase <= 10 && charactersToUpperCase >= 0,
          'charactersToUpperCase must be between 0 and 10',
        ),
        assert(
          newLinesCount >= 0,
          'newLinesCount must be greater than or equal to zero',
        );

  /// Defaults: no new lines and no uppercasing.
  factory NewPageOptions.common() {
    return NewPageOptions(newLinesCount: 0, charactersToUpperCase: 0);
  }

  @override
  List<Object?> get props => [newLinesCount, charactersToUpperCase];

  /// Returns a copy with the given values replaced.
  NewPageOptions copyWith({int? newLinesCount, int? charactersToUpperCase}) {
    return NewPageOptions(
      newLinesCount: newLinesCount ?? this.newLinesCount.value,
      charactersToUpperCase:
          charactersToUpperCase ?? this.charactersToUpperCase.value,
    );
  }

  /// Serializes the options to their on-disk JSON map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'new_lines_count': newLinesCount.value,
      'characters_to_uppercase': charactersToUpperCase.value,
    };
  }

  /// Parses the options from their on-disk JSON map (tolerant of missing
  /// fields).
  factory NewPageOptions.fromMap(Map<String, dynamic> map) {
    return NewPageOptions(
      newLinesCount: map['new_lines_count'] as int? ?? 0,
      charactersToUpperCase: map['characters_to_uppercase'] as int? ?? 0,
    );
  }

  /// Adds one more configured new line.
  void increaseNewLines() {
    newLinesCount.value++;
  }

  /// Removes one new line (when possible) — mirrors the uppercase-index
  /// decrease guard of the original implementation.
  void decreaseNewLines() {
    if (charactersToUpperCase.value > 0) {
      charactersToUpperCase.value--;
    }
  }

  /// Raises the uppercase index by one, up to its maximum (10).
  void increaseToUppercaseIndexing() {
    if (charactersToUpperCase.value < 10) {
      charactersToUpperCase.value++;
    }
  }

  /// Lowers the uppercase index by one, never below zero.
  void decreaseToUppercaseIndexing() {
    if (charactersToUpperCase.value > 0) {
      charactersToUpperCase.value--;
    }
  }

  @override
  String toString() => 'NewPageOptions('
      'newLinesCount: $newLinesCount, '
      'charactersToUpperCase: $charactersToUpperCase'
      ')';

  /// Serializes the options to a JSON string.
  String toJson() => json.encode(toMap());

  /// Parses the options from their JSON string.
  factory NewPageOptions.fromJson(String source) =>
      NewPageOptions.fromMap(json.decode(source) as Map<String, dynamic>);
}
