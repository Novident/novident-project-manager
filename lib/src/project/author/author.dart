import 'dart:convert';

import '../../constants/pattern_defaults.dart';

const double _maxUpperLimit = 2e51;

/// Author block of the project metadata (`files/metadata.json` → `author`).
///
/// [name] may contain several author names separated by commas; the helper
/// getters resolve a specific author, last name or first name by index.
class Author {
  /// Author name(s); several names must be divided by `,` to be detected
  /// correctly.
  final String name;

  /// State and/or country of the author.
  final String stateAndCountry;

  /// Street of the author's address.
  final String street;

  /// City of the author.
  final String city;

  /// Zip/postal code of the author.
  final String zipAndPostCode;

  /// Contact email.
  final String email;

  /// Contact phone number.
  final String phoneNumber;

  /// Website of the author.
  final String website;

  /// Builds the author; every field defaults to an empty string.
  const Author({
    this.name = "",
    this.stateAndCountry = "",
    this.street = "",
    this.city = "",
    this.zipAndPostCode = "",
    this.email = "",
    this.phoneNumber = "",
    this.website = "",
  });

  /// Splits [name] into individual author names (comma-separated).
  List<String> getAuthors() {
    if (!name.contains(',')) return <String>[name];
    return name.split(',');
  }

  /// Resolves the full author name of [index] (`all` returns every name).
  String getAuthorName(String index) {
    if (index == 'all') return name;
    if (!hasMoreThanFirst) return getAuthorName('1');
    return getAuthors().elementAt(
      (int.parse(index) - 1)
          .clamp(
            0,
            _maxUpperLimit,
          )
          .toInt(),
    );
  }

  /// Resolves the last name of the author at [index].
  String getLastName(String index) {
    if (!hasMoreThanFirst) return getLastName('1');
    if (index == 'all') {
      return getAuthors().map<String>((String author) {
        // if has no spaces, then get the name
        if (author.isEmpty ||
            !author.contains(PatternDefaults.whitespacesPattern)) {
          return author;
        }
        return author
            .split(
              PatternDefaults.whitespacesPattern,
            )
            .elementAt(1);
      }).join(',');
    }
    final String value = getAuthors().elementAt(
      (int.parse(index))
          .clamp(
            0,
            _maxUpperLimit,
          )
          .toInt(),
    );
    return value.split(PatternDefaults.whitespacesPattern).elementAt(1);
  }

  /// Resolves the first name of the author at [index].
  String getFirstname(String index) {
    if (!hasMoreThanFirst) return getFirstname('1');
    if (index == 'all') {
      return getAuthors().map<String>((String author) {
        // if has no spaces, then get the name
        if (author.isEmpty ||
            !author.contains(
              PatternDefaults.whitespacesPattern,
            )) {
          return author;
        }
        return author
            .split(
              PatternDefaults.whitespacesPattern,
            )
            .first;
      }).join(',');
    }
    return getAuthors()
        .elementAt(
          (int.parse(index))
              .clamp(
                0,
                _maxUpperLimit,
              )
              .toInt(),
        )
        .split(PatternDefaults.whitespacesPattern)
        .first;
  }

  /// Whether [name] contains more than one author.
  bool get hasMoreThanFirst => name.contains(',');

  /// Returns a copy with the given fields replaced.
  Author copyWith({
    String? name,
    String? stateAndCountry,
    String? street,
    String? city,
    String? zipAndPostCode,
    String? email,
    String? phoneNumber,
    String? website,
  }) {
    return Author(
      name: name ?? this.name,
      stateAndCountry: stateAndCountry ?? this.stateAndCountry,
      street: street ?? this.street,
      city: city ?? this.city,
      zipAndPostCode: zipAndPostCode ?? this.zipAndPostCode,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
    );
  }

  /// Serializes the author to its on-disk JSON map (snake_case keys).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'state_and_country': stateAndCountry,
      'street': street,
      'city': city,
      'zip_and_post_code': zipAndPostCode,
      'email': email,
      'phone_number': phoneNumber,
      'website': website,
    };
  }

  /// Parses the author from its on-disk JSON map (tolerant of missing fields).
  factory Author.fromMap(Map<String, dynamic> map) {
    return Author(
      name: map['name'] as String? ?? '',
      stateAndCountry: map['state_and_country'] as String? ?? '',
      street: map['street'] as String? ?? '',
      city: map['city'] as String? ?? '',
      zipAndPostCode: map['zip_and_post_code'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phone_number'] as String? ?? '',
      website: map['website'] as String? ?? '',
    );
  }

  /// Serializes the author to a JSON string.
  String toJson() => json.encode(toMap());

  /// Parses the author from its JSON string.
  factory Author.fromJson(String source) =>
      Author.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Author('
        'name: $name, '
        'stateAndCountry: $stateAndCountry, '
        'street: $street, '
        'city: $city, '
        'zipAndPostCode: $zipAndPostCode, '
        'email: $email, '
        'phoneNumber: $phoneNumber'
        ')';
  }

  @override
  bool operator ==(covariant Author other) {
    if (identical(this, other)) return true;

    return other.name == name &&
        other.stateAndCountry == stateAndCountry &&
        other.street == street &&
        other.city == city &&
        other.zipAndPostCode == zipAndPostCode &&
        other.email == email &&
        other.phoneNumber == phoneNumber &&
        other.website == website;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        stateAndCountry.hashCode ^
        street.hashCode ^
        city.hashCode ^
        zipAndPostCode.hashCode ^
        email.hashCode ^
        phoneNumber.hashCode ^
        website.hashCode;
  }
}
