import 'package:rdf_core/rdf_core.dart';

import 'identifier_issuer.dart';

/// Handles serialization of RDF quads for canonicalization hashing purposes.
/// This class encapsulates the logic for converting quads to their string
/// representations with special handling for blank nodes during the hashing process.
class QuadSerializer {
  final Map<BlankNodeTerm, String> blankNodeIdentifiers;

  QuadSerializer(this.blankNodeIdentifiers);

  /// Serializes a quad for first-degree hashing with special blank node handling.
  /// The reference identifier is treated specially - it gets mapped to '_:a',
  /// while other blank nodes get mapped to '_:z'.
  String serializeForFirstDegreeHashing(Quad quad, String referenceIdentifier) {
    final subject = _serializeTermForFirstDegree(quad.subject, referenceIdentifier);
    final predicate = _serializeTermForFirstDegree(quad.predicate, referenceIdentifier);
    final object = _serializeTermForFirstDegree(quad.object, referenceIdentifier);
    final graph = quad.graphName != null
        ? _serializeTermForFirstDegree(quad.graphName!, referenceIdentifier)
        : '';

    return '$subject $predicate $object $graph .'.trim();
  }

  /// Serializes a quad for N-degree hashing with proper identifier mapping.
  /// Uses an issuer to track temporary identifiers during the N-degree process.
  String serializeForNDegreeHashing(
    Quad quad,
    String referenceId,
    String relatedId,
    IdentifierIssuer issuer,
  ) {
    final subject = _serializeTermForNDegree(quad.subject, referenceId, relatedId, issuer);
    final predicate = _serializeTermForNDegree(quad.predicate, referenceId, relatedId, issuer);
    final object = _serializeTermForNDegree(quad.object, referenceId, relatedId, issuer);
    final graph = quad.graphName != null
        ? _serializeTermForNDegree(quad.graphName!, referenceId, relatedId, issuer)
        : '';

    return '$subject $predicate $object $graph .'.trim();
  }

  /// Serializes a term for first-degree hashing.
  String _serializeTermForFirstDegree(RdfTerm term, String referenceIdentifier) {
    if (term is BlankNodeTerm) {
      final identifier = blankNodeIdentifiers[term];
      if (identifier != null) {
        if (identifier == referenceIdentifier) {
          return '_:a';
        } else {
          return '_:z';
        }
      } else {
        return '_:z';
      }
    }
    return _serializeNonBlankTerm(term);
  }

  /// Serializes a term for N-degree hashing.
  String _serializeTermForNDegree(
    RdfTerm term,
    String referenceId,
    String relatedId,
    IdentifierIssuer issuer,
  ) {
    if (term is BlankNodeTerm) {
      final identifier = blankNodeIdentifiers[term];
      if (identifier == referenceId) {
        return '_:a';
      } else if (identifier == relatedId) {
        return '_:b';
      } else if (identifier != null && issuer.issuedIdentifiersMap.containsKey(identifier)) {
        return '_:${issuer.issuedIdentifiersMap[identifier]}';
      } else {
        return '_:z';
      }
    }
    return _serializeNonBlankTerm(term);
  }

  /// Serializes non-blank node terms (IRIs, literals).
  String _serializeNonBlankTerm(RdfTerm term) {
    if (term is IriTerm) {
      return '<${term.value}>';
    } else if (term is LiteralTerm) {
      final value = term.value;
      final escapedValue = value
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');
      if (term.language != null) {
        return '"$escapedValue"@${term.language}';
      } else if (term.datatype.value != 'http://www.w3.org/2001/XMLSchema#string') {
        return '"$escapedValue"^^<${term.datatype.value}>';
      } else {
        return '"$escapedValue"';
      }
    } else {
      // Default graph case
      return '';
    }
  }
}