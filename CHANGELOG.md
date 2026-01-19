# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-01-19

### Deprecated

- **This package is deprecated and no longer maintained.**
- All functionality has been moved to [`locorda_rdf_canonicalization`](https://pub.dev/packages/locorda_rdf_canonicalization) as part of the [locorda](https://github.com/locorda) project.
- Please migrate to the new package by replacing `rdf_canonicalization` with `locorda_rdf_canonicalization` in your `pubspec.yaml` and updating your imports.
- **Important:** All rdf_* packages have been moved. You must also migrate dependencies like `rdf_core` to [`locorda_rdf_core`](https://pub.dev/packages/locorda_rdf_core).
- This repository will be archived.


## [0.2.0] - 2025-09-28

### Fixed

- **Test Suite Compliance**: Fixed critical bugs to achieve full compliance with the official W3C RDF canonicalization test suite
- **Specification Alignment**: Re-implemented n-degree hashing algorithm to more closely align with the W3C specification
- **Implementation Structure**: Improved canonicalization implementation with better quad handling and processing

### Changed

- **Code Quality**: Introduced typedefs to improve code readability and maintainability
- **Test Infrastructure**: Added comprehensive official test suite for validation

## [0.1.0] - 2025-09-26

### Added

- **Initial Release**: RDF canonicalization library extracted for specialized canonicalization functionality
- **RDF Canonicalization API**: Complete canonicalization framework for RDF graph isomorphism and semantic equality
  - `CanonicalRdfDataset` and `CanonicalRdfGraph` classes for semantic RDF comparison
  - `canonicalize()`, `canonicalizeGraph()`, `isIsomorphic()`, and `isIsomorphicGraphs()` functions
  - `CanonicalizationOptions` and `CanonicalHashAlgorithm` for configurable canonicalization behavior
  - Support for SHA-256 and SHA-384 hash algorithms
  - Deterministic blank node labeling and canonical N-Quads output
