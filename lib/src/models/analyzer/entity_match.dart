/// Represents a matched code entity with its type and regex match.
class EntityMatch {
  /// The type of entity (class, enum, extension, mixin).
  final String type;

  /// The regex match containing the entity details.
  final RegExpMatch match;

  const EntityMatch({required this.type, required this.match});
}
