import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:rdf_core/rdf_core.dart';

import 'identifier_issuer.dart';

class CanonicalizationState {
  /// Ordered map that relates a blank node identifier to the quads in which they appear
  final Map<String, List<Quad>> blankNodeToQuadsMap;

  /// Ordered map that relates a hash to a list of blank node identifiers
  final Map<String, List<String>> hashToBlankNodesMap;

  /// Identifier issuer for canonical blank node identifiers
  final IdentifierIssuer canonicalIssuer;

  /// Map from BlankNodeTerm instances to their string identifiers
  final Map<BlankNodeTerm, String> blankNodeIdentifiers;

  CanonicalizationState({
    Map<String, List<Quad>>? blankNodeToQuadsMap,
    Map<String, List<String>>? hashToBlankNodesMap,
    IdentifierIssuer? canonicalIssuer,
    Map<BlankNodeTerm, String>? blankNodeIdentifiers,
  })  : blankNodeToQuadsMap = blankNodeToQuadsMap ?? {},
        hashToBlankNodesMap = hashToBlankNodesMap ?? {},
        canonicalIssuer = canonicalIssuer ?? IdentifierIssuer('c14n'),
        blankNodeIdentifiers = blankNodeIdentifiers ?? {};

  /// Hash First Degree Quads algorithm
  String hashFirstDegreeQuads(String identifier) {
    final quads = blankNodeToQuadsMap[identifier] ?? [];
    final nquads = <String>[];

    for (final quad in quads) {
      nquads.add(_serializeQuadForHashing(quad, identifier));
    }

    // Sort in Unicode code point order
    nquads.sort();

    // Concatenate and hash
    final concatenated = nquads.join('');
    final bytes = utf8.encode(concatenated);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Serialize a quad for hashing with special blank node handling
  String _serializeQuadForHashing(Quad quad, String referenceIdentifier) {
    final subject = _serializeTermForHashing(quad.subject, referenceIdentifier);
    final predicate =
        _serializeTermForHashing(quad.predicate, referenceIdentifier);
    final object = _serializeTermForHashing(quad.object, referenceIdentifier);
    final graph = quad.graphName != null
        ? _serializeTermForHashing(quad.graphName!, referenceIdentifier)
        : '';

    return '$subject $predicate $object $graph .'.trim();
  }

  /// Serialize a term for hashing with special blank node handling
  String _serializeTermForHashing(RdfTerm term, String referenceIdentifier) {
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
    } else if (term is IriTerm) {
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
      } else if (term.datatype.value !=
          'http://www.w3.org/2001/XMLSchema#string') {
        return '"$escapedValue"^^<${term.datatype.value}>';
      } else {
        return '"$escapedValue"';
      }
    } else {
      // Default graph case
      return '';
    }
  }

  /// Hash N-Degree Quads algorithm
  String hashNDegreeQuads(String identifier, IdentifierIssuer issuer) {
    // Initialize the data to hash
    final nquads = <String>[];

    // Issue a temporary identifier for the reference node
    final tempIssuer = issuer.clone();
    tempIssuer.issueIdentifier(identifier);

    // Get quads for this identifier
    final quads = blankNodeToQuadsMap[identifier] ?? [];

    // Find all related blank nodes (those that appear in quads with this identifier)
    final relatedBlankNodes =
        <String, String>{}; // identifier -> first-degree hash

    for (final quad in quads) {
      for (final term in [quad.subject, quad.object]) {
        if (term is BlankNodeTerm) {
          final relatedId = blankNodeIdentifiers[term];
          if (relatedId != null && relatedId != identifier) {
            if (!relatedBlankNodes.containsKey(relatedId)) {
              relatedBlankNodes[relatedId] = hashFirstDegreeQuads(relatedId);
            }
          }
        }
      }
    }

    // Sort related blank nodes by their first-degree hash for deterministic processing
    final sortedRelated = relatedBlankNodes.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Process each related blank node
    for (final entry in sortedRelated) {
      final relatedId = entry.key;

      // Create a branch issuer for this related node
      final branchIssuer = tempIssuer.clone();

      // Issue identifier for the related node
      branchIssuer.issueIdentifier(relatedId);

      // Serialize quads involving both nodes with special identifiers
      final relatedQuads = <String>[];

      for (final quad in quads) {
        bool involvesRelated = false;

        for (final term in [quad.subject, quad.object]) {
          if (term is BlankNodeTerm) {
            final termId = blankNodeIdentifiers[term];
            if (termId == relatedId) {
              involvesRelated = true;
              break;
            }
          }
        }

        if (involvesRelated) {
          relatedQuads.add(_serializeQuadForNDegreeHashing(
              quad, identifier, relatedId, branchIssuer));
        }
      }

      // Sort and add to hash data
      relatedQuads.sort();
      nquads.addAll(relatedQuads);
    }

    // Create final hash
    final concatenated = nquads.join('');
    final bytes = utf8.encode(concatenated);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Serialize quad for N-degree hashing with proper identifier mapping
  String _serializeQuadForNDegreeHashing(Quad quad, String referenceId,
      String relatedId, IdentifierIssuer issuer) {
    final subject = _serializeTermForNDegreeHashing(
        quad.subject, referenceId, relatedId, issuer);
    final predicate = _serializeTermForNDegreeHashing(
        quad.predicate, referenceId, relatedId, issuer);
    final object = _serializeTermForNDegreeHashing(
        quad.object, referenceId, relatedId, issuer);
    final graph = quad.graphName != null
        ? _serializeTermForNDegreeHashing(
            quad.graphName!, referenceId, relatedId, issuer)
        : '';

    return '$subject $predicate $object $graph .'.trim();
  }

  /// Serialize term for N-degree hashing
  String _serializeTermForNDegreeHashing(RdfTerm term, String referenceId,
      String relatedId, IdentifierIssuer issuer) {
    if (term is BlankNodeTerm) {
      final identifier = blankNodeIdentifiers[term];
      if (identifier == referenceId) {
        return '_:a';
      } else if (identifier == relatedId) {
        return '_:b';
      } else if (identifier != null &&
          issuer.issuedIdentifiersMap.containsKey(identifier)) {
        return '_:${issuer.issuedIdentifiersMap[identifier]}';
      } else {
        return '_:z';
      }
    } else if (term is IriTerm) {
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
      } else if (term.datatype.value !=
          'http://www.w3.org/2001/XMLSchema#string') {
        return '"$escapedValue"^^<${term.datatype.value}>';
      } else {
        return '"$escapedValue"';
      }
    } else {
      return '';
    }
  }

  /// Create a hash path for a blank node using N-degree hashing
  HashPathResult createHashPath(String identifier, IdentifierIssuer issuer) {
    final tempIssuer = issuer.clone();
    tempIssuer.issueIdentifier(identifier);
    final hash = hashNDegreeQuads(identifier, tempIssuer);

    return HashPathResult(
      hash: hash,
      identifier: identifier,
      issuer: tempIssuer,
    );
  }
}

/// Result of hash path computation
class HashPathResult {
  final String hash;
  final String identifier;
  final IdentifierIssuer issuer;

  HashPathResult({
    required this.hash,
    required this.identifier,
    required this.issuer,
  });
}
