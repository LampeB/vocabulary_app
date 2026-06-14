import 'package:freezed_annotation/freezed_annotation.dart';

part 'concept.freezed.dart';
part 'concept.g.dart';

@freezed
class Concept with _$Concept {
  const factory Concept({
    required String id,
    required String listId,
    String? category,
    String? notes,
    String? imageUrl,
    String? exampleFr,
    String? exampleKo,
    @Default(false) bool isSynced,
    @Default(false) bool isDeleted,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Concept;

  factory Concept.fromJson(Map<String, dynamic> json) => _$ConceptFromJson(json);
}
