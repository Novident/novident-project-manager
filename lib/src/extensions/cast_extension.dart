extension CastObject on Object {
  T cast<T>() {
    return this as T;
  }

  T? castOrNull<T>() {
    return this is T ? this as T : null;
  }
}

extension CastNullableObject on Object? {
  T? cast<T>() {
    return this == null ? null : this as T;
  }
}

extension OrAltObjects on String? {
  String orEmpty() => this == null ? '' : this!;
}
