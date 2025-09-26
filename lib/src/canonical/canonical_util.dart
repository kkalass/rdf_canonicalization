import 'package:rdf_core/rdf_core.dart';

import 'canonicalization_state.dart';
import 'identifier_issuer.dart';

enum CanonicalHashAlgorithm { sha256, sha384 }

class CanonicalizationOptions {
  final CanonicalHashAlgorithm hashAlgorithm;
  final String blankNodePrefix;

  const CanonicalizationOptions(
      {this.hashAlgorithm = CanonicalHashAlgorithm.sha256,
      this.blankNodePrefix = 'c14n'});
}

class CanonicalizedRdfDataset {
  final RdfDataset inputDataset;
  // Optional: if input was provided in a way that blank nodes had labels,
  // this map contains the mapping from blank node terms to their original labels.
  final Map<BlankNodeTerm, String>? inputIdentifiers;
  final Map<BlankNodeTerm, String> issuedIdentifiers;

  CanonicalizedRdfDataset(
      {required this.inputDataset,
      required this.inputIdentifiers,
      required this.issuedIdentifiers});
}

CanonicalizedRdfDataset toCanonicalizedRdfDataset(RdfDataset dataset,
    {Map<BlankNodeTerm, String>? inputLabels,
    CanonicalizationOptions? options}) {
  options ??= const CanonicalizationOptions();

  // Step 1: Create canonicalization state
  final state = _createCanonicalizationState(dataset, inputLabels, options);

  // Step 2: For every blank node identifier, compute first-degree hash

  for (final identifier in state.blankNodeToQuadsMap.keys) {
    final hash = state.hashFirstDegreeQuads(identifier);

    // Add to hash-to-blank-nodes map
    state.hashToBlankNodesMap.putIfAbsent(hash, () => []).add(identifier);
  }

  // Step 3: Process hashes in lexicographical order
  final sortedHashes = state.hashToBlankNodesMap.keys.toList()..sort();
  final nonUniqueHashes = <String>[];

  for (final hash in sortedHashes) {
    final identifiers = state.hashToBlankNodesMap[hash]!;

    if (identifiers.length == 1) {
      // Unique hash - issue canonical identifier immediately
      state.canonicalIssuer.issueIdentifier(identifiers.first);
    } else {
      // Non-unique hash - handle later
      nonUniqueHashes.add(hash);
    }
  }

  // Step 4: For every non-unique hash, use N-degree hashing and issue canonical identifiers
  for (final hash in nonUniqueHashes) {
    final identifiers = state.hashToBlankNodesMap[hash]!;

    // Create hash path list for N-degree processing
    final hashPathList = <HashPathResult>[];

    for (final identifier in identifiers) {
      // Skip if already canonically labeled
      if (state.canonicalIssuer.issuedIdentifiersMap.containsKey(identifier)) {
        continue;
      }

      // Create temporary issuer for this branch
      final tempIssuer = IdentifierIssuer('_:b');

      // Create hash path result using N-degree hashing
      final hashPathResult = state.createHashPath(identifier, tempIssuer);
      hashPathList.add(hashPathResult);
    }

    // Sort hash path list by hash value for deterministic ordering
    hashPathList.sort((a, b) => a.hash.compareTo(b.hash));

    // Issue canonical identifiers in sorted order
    for (final hashPath in hashPathList) {
      if (!state.canonicalIssuer.issuedIdentifiersMap
          .containsKey(hashPath.identifier)) {
        state.canonicalIssuer.issueIdentifier(hashPath.identifier);

        // Merge any temporary identifiers issued during this process
        for (final entry in hashPath.issuer.issuedIdentifiersMap.entries) {
          final tempOriginal = entry.key;
          if (tempOriginal != hashPath.identifier &&
              !state.canonicalIssuer.issuedIdentifiersMap
                  .containsKey(tempOriginal)) {
            state.canonicalIssuer.issueIdentifier(tempOriginal);
          }
        }
      }
    }
  }

  // Step 5: Build the result
  final issuedIdentifiers = <BlankNodeTerm, String>{};
  for (final entry in state.blankNodeIdentifiers.entries) {
    final blankNode = entry.key;
    final originalIdentifier = entry.value;
    final canonicalIdentifier =
        state.canonicalIssuer.issuedIdentifiersMap[originalIdentifier];
    if (canonicalIdentifier != null) {
      issuedIdentifiers[blankNode] = canonicalIdentifier;
    }
  }

  return CanonicalizedRdfDataset(
    inputDataset: dataset,
    inputIdentifiers: inputLabels,
    issuedIdentifiers: issuedIdentifiers,
  );
}

CanonicalizedRdfDataset toCanonicalizedRdfDatasetFromNQuads(String nquads,
    {CanonicalizationOptions? options}) {
  NQuadsDecoder decoder = NQuadsDecoder();
  final (blankNodeLabels: inputLabels, dataset: inputDataset) =
      decoder.decode(nquads);

  return toCanonicalizedRdfDataset(inputDataset,
      inputLabels: inputLabels, options: options);
}

String toNQuads(CanonicalizedRdfDataset canonicalized,
    {CanonicalizationOptions? options}) {
  final NQuadsEncoder encoder =
      NQuadsEncoder(options: NQuadsEncoderOptions(canonical: true));
  return encoder.encode(canonicalized.inputDataset,
      blankNodeLabels: canonicalized.issuedIdentifiers,
      generateNewBlankNodeLabels: false);
}

/// https://www.w3.org/TR/rdf-canon/#canonicalization states: "Canonicalization is the process of transforming an input dataset to its serialized canonical form"
String canonicalize(RdfDataset dataset, {CanonicalizationOptions? options}) {
  options ??= const CanonicalizationOptions();
  final canonicalized = toCanonicalizedRdfDataset(dataset, options: options);
  return toNQuads(canonicalized, options: options);
}

String canonicalizeGraph(RdfGraph graph, {CanonicalizationOptions? options}) {
  return canonicalize(RdfDataset.fromDefaultGraph(graph), options: options);
}

bool isIsomorphic(RdfDataset a, RdfDataset b,
    {CanonicalizationOptions? options}) {
  options ??= const CanonicalizationOptions();
  final canA = canonicalize(a, options: options);
  final canB = canonicalize(b, options: options);

  // Two datasets are isomorphic if their canonical serializations match
  return canA == canB;
}

bool isIsomorphicGraphs(RdfGraph a, RdfGraph b,
    {CanonicalizationOptions? options}) {
  final canA = canonicalizeGraph(a, options: options);
  final canB = canonicalizeGraph(b, options: options);

  // Two graphs are isomorphic if their canonical serializations match
  return canA == canB;
}

/// Helper function to create canonicalization state from dataset
CanonicalizationState _createCanonicalizationState(
    RdfDataset dataset, Map<BlankNodeTerm, String>? inputLabels, CanonicalizationOptions options) {
  final state = CanonicalizationState(options: options);

  // Generate identifiers for blank nodes if not provided
  final blankNodeIdentifiers = <BlankNodeTerm, String>{};
  if (inputLabels != null) {
    blankNodeIdentifiers.addAll(inputLabels);
  } else {
    // Generate temporary identifiers
    var counter = 0;
    final seen = <BlankNodeTerm>{};

    for (final quad in dataset.quads) {
      for (final term in [quad.subject, quad.object]) {
        if (term is BlankNodeTerm && !seen.contains(term)) {
          blankNodeIdentifiers[term] = '_:n$counter';
          seen.add(term);
          counter++;
        }
      }
    }
  }

  // Populate state
  state.blankNodeIdentifiers.addAll(blankNodeIdentifiers);

  // Build blank node to quads map
  for (final quad in dataset.quads) {
    for (final term in [quad.subject, quad.object]) {
      if (term is BlankNodeTerm) {
        final identifier = blankNodeIdentifiers[term];
        if (identifier != null) {
          state.blankNodeToQuadsMap.putIfAbsent(identifier, () => []).add(quad);
        }
      }
    }
  }

  return state;
}
