import 'blank_node_hasher.dart';
import 'identifier_issuer.dart';

/// Result of hash path computation for N-degree hashing.
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

/// Handles the computation of hash paths for blank nodes during N-degree hashing.
/// This class encapsulates the logic for creating deterministic paths through
/// the graph structure when computing N-degree hashes.
class HashPathCalculator {
  final BlankNodeHasher hasher;

  HashPathCalculator(this.hasher);

  /// Creates a hash path for a blank node using N-degree hashing.
  /// This is used when multiple blank nodes have the same first-degree hash
  /// and we need to differentiate them using their broader context.
  HashPathResult createHashPath(String identifier, IdentifierIssuer issuer) {
    final tempIssuer = issuer.clone();
    tempIssuer.issueIdentifier(identifier);
    final hash = hasher.computeNDegreeHash(identifier, tempIssuer);

    return HashPathResult(
      hash: hash,
      identifier: identifier,
      issuer: tempIssuer,
    );
  }

  /// Creates hash paths for multiple identifiers and returns them sorted by hash.
  /// This is useful for processing groups of blank nodes that share the same
  /// first-degree hash in a deterministic order.
  List<HashPathResult> createSortedHashPaths(
    List<String> identifiers,
    IdentifierIssuer baseIssuer,
  ) {
    final hashPathList = <HashPathResult>[];

    for (final identifier in identifiers) {
      // Create temporary issuer for this branch
      final tempIssuer = IdentifierIssuer('_:b');

      // Create hash path result using N-degree hashing
      final hashPathResult = createHashPath(identifier, tempIssuer);
      hashPathList.add(hashPathResult);
    }

    // Sort hash path list by hash value for deterministic ordering
    hashPathList.sort((a, b) => a.hash.compareTo(b.hash));

    return hashPathList;
  }
}