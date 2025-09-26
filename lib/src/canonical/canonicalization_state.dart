import 'package:rdf_core/rdf_core.dart';

import 'canonical_util.dart';
import 'identifier_issuer.dart';

/// Pure state container for RDF canonicalization process.
/// This class holds only the state data needed for canonicalization
/// without any algorithmic logic, following clean architecture principles.
class CanonicalizationState {
  /// Ordered map that relates a blank node identifier to the quads in which they appear
  final Map<String, List<Quad>> blankNodeToQuadsMap;

  /// Ordered map that relates a hash to a list of blank node identifiers
  final Map<String, List<String>> hashToBlankNodesMap;

  /// Identifier issuer for canonical blank node identifiers
  final IdentifierIssuer canonicalIssuer;

  /// Map from BlankNodeTerm instances to their string identifiers
  final Map<BlankNodeTerm, String> blankNodeIdentifiers;

  /// Canonicalization options including hash algorithm
  final CanonicalizationOptions options;

  CanonicalizationState({
    Map<String, List<Quad>>? blankNodeToQuadsMap,
    Map<String, List<String>>? hashToBlankNodesMap,
    IdentifierIssuer? canonicalIssuer,
    Map<BlankNodeTerm, String>? blankNodeIdentifiers,
    CanonicalizationOptions? options,
  })  : blankNodeToQuadsMap = blankNodeToQuadsMap ?? {},
        hashToBlankNodesMap = hashToBlankNodesMap ?? {},
        canonicalIssuer = canonicalIssuer ?? IdentifierIssuer((options ?? const CanonicalizationOptions()).blankNodePrefix),
        blankNodeIdentifiers = blankNodeIdentifiers ?? {},
        options = options ?? const CanonicalizationOptions();

}
