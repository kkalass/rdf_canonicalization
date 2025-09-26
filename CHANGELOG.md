# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.19] - TBD

### Added

- **RDF Canonicalization API**: New canonicalization framework for RDF graph isomorphism and semantic equality
  - `CanonicalRdfDataset` and `CanonicalRdfGraph` classes for semantic RDF comparison
  - `canonicalize()`, `canonicalizeGraph()`, and `isIsomorphic()` functions for RDF canonicalization operations
  - `CanonicalizationOptions` and `CanonicalHashAlgorithm` for configurable canonicalization behavior
  - **Note**: API structure established, full canonicalization algorithm implementation pending
