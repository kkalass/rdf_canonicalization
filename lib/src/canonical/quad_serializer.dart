import 'package:rdf_core/rdf_core.dart';
import 'quad_extension.dart';

import 'identifier_issuer.dart';

/// Handles serialization of RDF quads for canonicalization hashing purposes.
/// This class encapsulates the logic for converting quads to their string
/// representations with special handling for blank nodes during the hashing process.
class QuadSerializer {
  final Map<BlankNodeTerm, String> blankNodeIdentifiers;
  final NQuadsEncoder canonicalEncoder =
      NQuadsEncoder(options: NQuadsEncoderOptions(canonical: true));

  QuadSerializer(this.blankNodeIdentifiers);

  /// Serializes a quad for first-degree hashing with special blank node handling.
  /// The reference identifier is treated specially - it gets mapped to '_:a',
  /// while other blank nodes get mapped to '_:z'.
  String toFirstDegreeNQuad(Quad quad, String referenceIdentifier) {
    final hIdentifiers = {
      for (final bnode in quad.blankNodes)
        bnode: blankNodeIdentifiers[bnode] == referenceIdentifier ? 'a' : 'z'
    };
    // TODO: optimize by implementing encodeQuad in canonicalEncoder
    return canonicalEncoder.encode(RdfDataset.fromQuads([quad]),
        blankNodeLabels: hIdentifiers);
  }

  /// Serializes a quad for N-degree hashing with proper identifier mapping.
  /// Uses an issuer to track temporary identifiers during the N-degree process.
  String serializeForNDegreeHashing(
    Quad quad,
    String referenceId,
    String relatedId,
    IdentifierIssuer issuer,
  ) {
    final hIdentifiers = {
      for (final bnode in quad.blankNodes)
        bnode: _identifierForNDegree(bnode, referenceId, relatedId, issuer)
    };
    // TODO: optimize by implementing encodeQuad in canonicalEncoder
    return canonicalEncoder.encode(RdfDataset.fromQuads([quad]),
        blankNodeLabels: hIdentifiers);
  }

  /// Serializes a term for N-degree hashing.
  String _identifierForNDegree(
    BlankNodeTerm bnode,
    String referenceId,
    String relatedId,
    IdentifierIssuer issuer,
  ) {
    final identifier = blankNodeIdentifiers[bnode]!;
    if (identifier == referenceId) {
      return 'a';
    } else if (identifier == relatedId) {
      return 'b';
    } else if (issuer.issuedIdentifiersMap.containsKey(identifier)) {
      return issuer.issuedIdentifiersMap[identifier]!;
    } else {
      return 'z';
    }
  }
}
