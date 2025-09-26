# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - TBD

### Added

- **Initial Release**: RDF canonicalization library extracted for specialized canonicalization functionality
- **RDF Canonicalization API**: Complete canonicalization framework for RDF graph isomorphism and semantic equality
  - `CanonicalRdfDataset` and `CanonicalRdfGraph` classes for semantic RDF comparison
  - `canonicalize()`, `canonicalizeGraph()`, `isIsomorphic()`, and `isIsomorphicGraphs()` functions
  - `CanonicalizationOptions` and `CanonicalHashAlgorithm` for configurable canonicalization behavior
  - Support for SHA-256 and SHA-384 hash algorithms
  - Deterministic blank node labeling and canonical N-Quads output
