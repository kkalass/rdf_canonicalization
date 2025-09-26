class IdentifierIssuer {
  String identifierPrefix;
  int identifierCounter;
  final Map<String, String> issuedIdentifiersMap;

  IdentifierIssuer([String? identifierPrefix])
      : identifierPrefix = identifierPrefix ?? 'c14n',
        identifierCounter = 0,
        issuedIdentifiersMap = <String, String>{};

  String issueIdentifier(String existingIdentifier) {
    // Step 1: If there is a map entry for existing identifier in issued identifiers map, return it.
    if (issuedIdentifiersMap.containsKey(existingIdentifier)) {
      return issuedIdentifiersMap[existingIdentifier]!;
    }

    // Step 2: Generate issued identifier by concatenating identifier prefix with the string value of identifier counter.
    final issuedIdentifier = '$identifierPrefix$identifierCounter';

    // Step 3: Add an entry mapping existing identifier to issued identifier to the issued identifiers map.
    issuedIdentifiersMap[existingIdentifier] = issuedIdentifier;

    // Step 4: Increment identifier counter.
    identifierCounter++;

    // Step 5: Return issued identifier.
    return issuedIdentifier;
  }

  IdentifierIssuer clone() {
    final cloned = IdentifierIssuer(identifierPrefix);
    cloned.identifierCounter = identifierCounter;
    cloned.issuedIdentifiersMap.addAll(issuedIdentifiersMap);
    return cloned;
  }
}
