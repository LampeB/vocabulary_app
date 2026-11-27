import 'dart:convert' show jsonEncode;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String starterConceptId(String listId, Object seedId) =>
    _uuid.v5(listId, jsonEncode(['concept', seedId]));

String starterVariantId(
  String conceptId,
  String language,
  int position,
  int occurrence,
) => _uuid.v5(
  conceptId,
  jsonEncode(['variant', language, position, occurrence]),
);
