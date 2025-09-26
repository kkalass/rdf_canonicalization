import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:rdf_core/rdf_core.dart';

import 'canonical_util.dart';
import 'identifier_issuer.dart';
import 'quad_serializer.dart';

/// Handles hash computation for blank nodes during RDF canonicalization.
/// Encapsulates the logic for both first-degree and N-degree hash computation
/// as specified in the RDF Dataset Canonicalization specification.
class BlankNodeHasher {
  final Map<String, List<Quad>> blankNodeToQuadsMap;
  final Map<BlankNodeTerm, String> blankNodeIdentifiers;
  final QuadSerializer quadSerializer;
  final CanonicalizationOptions options;

  BlankNodeHasher({
    required this.blankNodeToQuadsMap,
    required this.blankNodeIdentifiers,
    required this.options,
  }) : quadSerializer = QuadSerializer(blankNodeIdentifiers);

  /// Get the hash function based on the configured algorithm.
  Hash _getHashFunction() {
    switch (options.hashAlgorithm) {
      case CanonicalHashAlgorithm.sha256:
        return sha256;
      case CanonicalHashAlgorithm.sha384:
        return sha384;
    }
  }

  /// Computes the first-degree hash for a blank node identifier.
  /// This hash is based only on the immediate quads that contain the blank node.
  String computeFirstDegreeHash(String identifier) {
    final quads = blankNodeToQuadsMap[identifier] ?? [];
    final nquads = <String>[];

    for (final quad in quads) {
      nquads.add(quadSerializer.serializeForFirstDegreeHashing(quad, identifier));
    }

    // Sort in Unicode code point order for deterministic results
    nquads.sort();

    // Concatenate and hash
    final concatenated = nquads.join('');
    final bytes = utf8.encode(concatenated);
    final digest = _getHashFunction().convert(bytes);
    return digest.toString();
  }

  /// Computes the N-degree hash for a blank node identifier.
  /// This is used when first-degree hashes are not unique and considers
  /// the broader context of related blank nodes.
  String computeNDegreeHash(String identifier, IdentifierIssuer issuer) {
    final nquads = <String>[];

    // Issue a temporary identifier for the reference node
    final tempIssuer = issuer.clone();
    tempIssuer.issueIdentifier(identifier);

    // Get quads for this identifier
    final quads = blankNodeToQuadsMap[identifier] ?? [];

    // Find all related blank nodes and their first-degree hashes
    final relatedBlankNodes = _findRelatedBlankNodes(quads, identifier);

    // Sort related blank nodes by their first-degree hash for deterministic processing
    final sortedRelated = relatedBlankNodes.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Process each related blank node
    for (final entry in sortedRelated) {
      final relatedId = entry.key;

      // Create a branch issuer for this related node
      final branchIssuer = tempIssuer.clone();
      branchIssuer.issueIdentifier(relatedId);

      // Serialize quads involving both nodes
      final relatedQuads = _getQuadsInvolvingRelatedNode(quads, identifier, relatedId, branchIssuer);

      // Sort and add to hash data
      relatedQuads.sort();
      nquads.addAll(relatedQuads);
    }

    // Create final hash
    final concatenated = nquads.join('');
    final bytes = utf8.encode(concatenated);
    final digest = _getHashFunction().convert(bytes);
    return digest.toString();
  }

  /// Finds all blank nodes that are related to the given identifier
  /// (appear in the same quads) and returns their first-degree hashes.
  Map<String, String> _findRelatedBlankNodes(List<Quad> quads, String identifier) {
    final relatedBlankNodes = <String, String>{};

    for (final quad in quads) {
      for (final term in [quad.subject, quad.object]) {
        if (term is BlankNodeTerm) {
          final relatedId = blankNodeIdentifiers[term];
          if (relatedId != null && relatedId != identifier) {
            if (!relatedBlankNodes.containsKey(relatedId)) {
              relatedBlankNodes[relatedId] = computeFirstDegreeHash(relatedId);
            }
          }
        }
      }
    }

    return relatedBlankNodes;
  }

  /// Gets all quads that involve both the reference identifier and the related identifier,
  /// serialized for N-degree hashing.
  List<String> _getQuadsInvolvingRelatedNode(
    List<Quad> quads,
    String identifier,
    String relatedId,
    IdentifierIssuer branchIssuer,
  ) {
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
        relatedQuads.add(quadSerializer.serializeForNDegreeHashing(
          quad,
          identifier,
          relatedId,
          branchIssuer,
        ));
      }
    }

    return relatedQuads;
  }
}