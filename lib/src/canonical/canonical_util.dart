import 'package:rdf_core/rdf_core.dart';

import 'blank_node_hasher.dart';
import 'hash_path_calculator.dart';
import 'identifier_issuer.dart';
import 'quad_extension.dart';

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
  final RdfDataset canonicalDataset;
  // Optional: if input was provided in a way that blank nodes had labels,
  // this map contains the mapping from blank node terms to their original labels.
  final Map<BlankNodeTerm, String>? inputIdentifiers;
  final Map<BlankNodeTerm, String> issuedIdentifiers;

  CanonicalizedRdfDataset(
      {required this.inputDataset,
      required this.canonicalDataset,
      required this.inputIdentifiers,
      required this.issuedIdentifiers});
}

CanonicalizedRdfDataset toCanonicalizedRdfDataset(RdfDataset dataset,
    {Map<BlankNodeTerm, String>? inputLabels,
    CanonicalizationOptions? options}) {
  options ??= const CanonicalizationOptions();

  // Step 0: Deduplicate the dataset (RDF datasets should have set semantics)
  final allQuads = _deduplicateQuads(dataset);

  // Step 1: Create canonicalization state
  final (
    blankNodeToQuadsMap: blankNodeToQuadsMap,
    blankNodeIdentifiers: blankNodeIdentifiers
  ) = _createCanonicalizationState(allQuads, inputLabels, options);

  // Step 2: For every blank node identifier, compute first-degree hash
  final hasher = BlankNodeHasher(
    blankNodeToQuadsMap: blankNodeToQuadsMap,
    blankNodeIdentifiers: blankNodeIdentifiers,
    options: options,
  );

  final hashToBlankNodesMap = <String, List<String>>{};
  for (final identifier in blankNodeToQuadsMap.keys) {
    final hash = hasher.computeFirstDegreeHash(identifier);

    // Add to hash-to-blank-nodes map
    hashToBlankNodesMap.putIfAbsent(hash, () => []).add(identifier);
  }

  // Step 3: Process hashes in lexicographical order
  final sortedHashes = hashToBlankNodesMap.keys.toList()..sort();
  final nonUniqueHashes = <String>[];
  final canonicalIssuer = IdentifierIssuer(options.blankNodePrefix);
  for (final hash in sortedHashes) {
    final identifiers = hashToBlankNodesMap[hash]!;

    if (identifiers.length == 1) {
      // Unique hash - issue canonical identifier immediately
      canonicalIssuer.issueIdentifier(identifiers.first);
    } else {
      // Non-unique hash - handle later
      nonUniqueHashes.add(hash);
    }
  }

  // Step 4: For every non-unique hash, use N-degree hashing and issue canonical identifiers
  final hashPathCalculator = HashPathCalculator(hasher);

  for (final hash in nonUniqueHashes) {
    final identifiers = hashToBlankNodesMap[hash]!;

    // Filter out already canonically labeled identifiers
    final unlabeledIdentifiers = identifiers
        .where((id) => !canonicalIssuer.issuedIdentifiersMap.containsKey(id))
        .toList();

    if (unlabeledIdentifiers.isEmpty) continue;

    // Create sorted hash paths for N-degree processing
    final hashPathList = hashPathCalculator.createSortedHashPaths(
      unlabeledIdentifiers,
      canonicalIssuer,
    );

    // Issue canonical identifiers in sorted order
    for (final hashPath in hashPathList) {
      if (!canonicalIssuer.issuedIdentifiersMap
          .containsKey(hashPath.identifier)) {
        canonicalIssuer.issueIdentifier(hashPath.identifier);

        // Merge any temporary identifiers issued during this process
        for (final entry in hashPath.issuer.issuedIdentifiersMap.entries) {
          final tempOriginal = entry.key;
          if (tempOriginal != hashPath.identifier &&
              !canonicalIssuer.issuedIdentifiersMap.containsKey(tempOriginal)) {
            canonicalIssuer.issueIdentifier(tempOriginal);
          }
        }
      }
    }
  }

  // Step 5: Build the result
  final issuedIdentifiers = <BlankNodeTerm, String>{};
  for (final entry in blankNodeIdentifiers.entries) {
    final blankNode = entry.key;
    final originalIdentifier = entry.value;
    final canonicalIdentifier =
        canonicalIssuer.issuedIdentifiersMap[originalIdentifier];
    if (canonicalIdentifier != null) {
      issuedIdentifiers[blankNode] = canonicalIdentifier;
    }
  }

  return CanonicalizedRdfDataset(
    inputDataset: dataset,
    inputIdentifiers: inputLabels,
    issuedIdentifiers: issuedIdentifiers,
    // TODO: convert deduplicatedDataset to List and sort by N-Quads canonical order?
    canonicalDataset: RdfDataset.fromQuads(allQuads),
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
({
  Map<String, Set<Quad>> blankNodeToQuadsMap,
  Map<BlankNodeTerm, String> blankNodeIdentifiers
}) _createCanonicalizationState(Iterable<Quad> dataset,
    Map<BlankNodeTerm, String>? inputLabels, CanonicalizationOptions options) {
  // Generate identifiers for blank nodes if not provided
  final blankNodeIdentifiers = <BlankNodeTerm, String>{
    if (inputLabels != null) ...inputLabels
  };
  final identifiers = <String>{if (inputLabels != null) ...inputLabels.values};

  final Map<String, Set<Quad>> blankNodeToQuadsMap = {};
  // Generate temporary identifiers and track the mentions of blank nodes
  var counter = 0;
  for (final quad in dataset) {
    for (final bnode in quad.blankNodes) {
      String? identifier = blankNodeIdentifiers[bnode];
      if (identifier == null) {
        // should not happen, but just in case, avoid collisions
        while (identifiers.contains(identifier = '_:n$counter')) {
          counter++;
        }
        identifiers.add(identifier);
        blankNodeIdentifiers[bnode] = identifier;
      }
      blankNodeToQuadsMap.putIfAbsent(identifier, () => {}).add(quad);
    }
  }

  return (
    blankNodeIdentifiers: blankNodeIdentifiers,
    blankNodeToQuadsMap: blankNodeToQuadsMap
  );
}

/// Deduplicate an RDF dataset to ensure set semantics (no duplicate quads)
Set<Quad> _deduplicateQuads(RdfDataset dataset) {
  final uniqueQuads = <Quad>{};
  for (final quad in dataset.quads) {
    uniqueQuads.add(quad);
  }
  return uniqueQuads;
}
