import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';
import 'package:rdf_canonicalization/src/canonical/canonical_util.dart';

void main() {
  group('RDF Canonicalization', () {
    test('should canonicalize simple blank node graph', () {
      // Create a simple graph with blank nodes
      final bnode1 = BlankNodeTerm();
      final bnode2 = BlankNodeTerm();
      final predicate = const IriTerm('http://example.org/knows');
      final name = const IriTerm('http://example.org/name');
      final literal1 = LiteralTerm.string('Alice');
      final literal2 = LiteralTerm.string('Bob');

      final triples = [
        Triple(bnode1, name, literal1),
        Triple(bnode1, predicate, bnode2),
        Triple(bnode2, name, literal2),
      ];

      final graph = RdfGraph.fromTriples(triples);
      final dataset = RdfDataset.fromDefaultGraph(graph);

      // Canonicalize
      final canonicalized = toCanonicalizedRdfDataset(dataset);

      // Verify that canonical identifiers were issued
      expect(canonicalized.issuedIdentifiers.length, equals(2));
      expect(canonicalized.issuedIdentifiers.values.toSet().length,
          equals(2)); // All different

      // Check that identifiers start with 'c14n'
      for (final id in canonicalized.issuedIdentifiers.values) {
        expect(id, startsWith('c14n'));
      }
    });

    test('should produce deterministic canonical identifiers', () {
      // Create identical graphs with different blank node instances
      final createGraph = () {
        final bnode1 = BlankNodeTerm();
        final bnode2 = BlankNodeTerm();
        final predicate = const IriTerm('http://example.org/knows');
        final name = const IriTerm('http://example.org/name');
        final literal1 = LiteralTerm.string('Alice');
        final literal2 = LiteralTerm.string('Bob');

        final triples = [
          Triple(bnode1, name, literal1),
          Triple(bnode1, predicate, bnode2),
          Triple(bnode2, name, literal2),
        ];

        return RdfDataset.fromDefaultGraph(RdfGraph.fromTriples(triples));
      };

      final dataset1 = createGraph();
      final dataset2 = createGraph();

      final canonicalized1 = toCanonicalizedRdfDataset(dataset1);
      final canonicalized2 = toCanonicalizedRdfDataset(dataset2);

      // Convert to canonical N-Quads for comparison
      final nquads1 = toNQuads(canonicalized1);
      final nquads2 = toNQuads(canonicalized2);

      // Should produce identical canonical forms
      expect(nquads1, equals(nquads2));
    });

    test('should handle single blank node', () {
      final bnode = BlankNodeTerm();
      final name = const IriTerm('http://example.org/name');
      final literal = LiteralTerm.string('Alice');

      final triple = Triple(bnode, name, literal);
      final graph = RdfGraph.fromTriples([triple]);
      final dataset = RdfDataset.fromDefaultGraph(graph);

      final canonicalized = toCanonicalizedRdfDataset(dataset);

      expect(canonicalized.issuedIdentifiers.length, equals(1));
      expect(canonicalized.issuedIdentifiers.values.first, equals('c14n0'));
    });

    test('should handle graph with no blank nodes', () {
      final subject = const IriTerm('http://example.org/alice');
      final name = const IriTerm('http://example.org/name');
      final literal = LiteralTerm.string('Alice');

      final triple = Triple(subject, name, literal);
      final graph = RdfGraph.fromTriples([triple]);
      final dataset = RdfDataset.fromDefaultGraph(graph);

      final canonicalized = toCanonicalizedRdfDataset(dataset);

      expect(canonicalized.issuedIdentifiers.isEmpty, isTrue);
    });
  });
}
