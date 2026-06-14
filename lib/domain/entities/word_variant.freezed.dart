// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'word_variant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

WordVariant _$WordVariantFromJson(Map<String, dynamic> json) {
  return _WordVariant.fromJson(json);
}

/// @nodoc
mixin _$WordVariant {
  String get id => throw _privateConstructorUsedError;
  String get conceptId => throw _privateConstructorUsedError;
  String get word => throw _privateConstructorUsedError;
  String get langCode => throw _privateConstructorUsedError;
  String get registerTag => throw _privateConstructorUsedError;
  List<String> get contextTags => throw _privateConstructorUsedError;
  bool get isPrimary => throw _privateConstructorUsedError;
  String? get audioHash => throw _privateConstructorUsedError;
  String? get audioVoiceId => throw _privateConstructorUsedError;
  int get position => throw _privateConstructorUsedError;
  bool get isSynced => throw _privateConstructorUsedError;
  bool get isDeleted => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this WordVariant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WordVariant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WordVariantCopyWith<WordVariant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WordVariantCopyWith<$Res> {
  factory $WordVariantCopyWith(
          WordVariant value, $Res Function(WordVariant) then) =
      _$WordVariantCopyWithImpl<$Res, WordVariant>;
  @useResult
  $Res call(
      {String id,
      String conceptId,
      String word,
      String langCode,
      String registerTag,
      List<String> contextTags,
      bool isPrimary,
      String? audioHash,
      String? audioVoiceId,
      int position,
      bool isSynced,
      bool isDeleted,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$WordVariantCopyWithImpl<$Res, $Val extends WordVariant>
    implements $WordVariantCopyWith<$Res> {
  _$WordVariantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WordVariant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? conceptId = null,
    Object? word = null,
    Object? langCode = null,
    Object? registerTag = null,
    Object? contextTags = null,
    Object? isPrimary = null,
    Object? audioHash = freezed,
    Object? audioVoiceId = freezed,
    Object? position = null,
    Object? isSynced = null,
    Object? isDeleted = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      conceptId: null == conceptId
          ? _value.conceptId
          : conceptId // ignore: cast_nullable_to_non_nullable
              as String,
      word: null == word
          ? _value.word
          : word // ignore: cast_nullable_to_non_nullable
              as String,
      langCode: null == langCode
          ? _value.langCode
          : langCode // ignore: cast_nullable_to_non_nullable
              as String,
      registerTag: null == registerTag
          ? _value.registerTag
          : registerTag // ignore: cast_nullable_to_non_nullable
              as String,
      contextTags: null == contextTags
          ? _value.contextTags
          : contextTags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isPrimary: null == isPrimary
          ? _value.isPrimary
          : isPrimary // ignore: cast_nullable_to_non_nullable
              as bool,
      audioHash: freezed == audioHash
          ? _value.audioHash
          : audioHash // ignore: cast_nullable_to_non_nullable
              as String?,
      audioVoiceId: freezed == audioVoiceId
          ? _value.audioVoiceId
          : audioVoiceId // ignore: cast_nullable_to_non_nullable
              as String?,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      isSynced: null == isSynced
          ? _value.isSynced
          : isSynced // ignore: cast_nullable_to_non_nullable
              as bool,
      isDeleted: null == isDeleted
          ? _value.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WordVariantImplCopyWith<$Res>
    implements $WordVariantCopyWith<$Res> {
  factory _$$WordVariantImplCopyWith(
          _$WordVariantImpl value, $Res Function(_$WordVariantImpl) then) =
      __$$WordVariantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String conceptId,
      String word,
      String langCode,
      String registerTag,
      List<String> contextTags,
      bool isPrimary,
      String? audioHash,
      String? audioVoiceId,
      int position,
      bool isSynced,
      bool isDeleted,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$WordVariantImplCopyWithImpl<$Res>
    extends _$WordVariantCopyWithImpl<$Res, _$WordVariantImpl>
    implements _$$WordVariantImplCopyWith<$Res> {
  __$$WordVariantImplCopyWithImpl(
      _$WordVariantImpl _value, $Res Function(_$WordVariantImpl) _then)
      : super(_value, _then);

  /// Create a copy of WordVariant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? conceptId = null,
    Object? word = null,
    Object? langCode = null,
    Object? registerTag = null,
    Object? contextTags = null,
    Object? isPrimary = null,
    Object? audioHash = freezed,
    Object? audioVoiceId = freezed,
    Object? position = null,
    Object? isSynced = null,
    Object? isDeleted = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$WordVariantImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      conceptId: null == conceptId
          ? _value.conceptId
          : conceptId // ignore: cast_nullable_to_non_nullable
              as String,
      word: null == word
          ? _value.word
          : word // ignore: cast_nullable_to_non_nullable
              as String,
      langCode: null == langCode
          ? _value.langCode
          : langCode // ignore: cast_nullable_to_non_nullable
              as String,
      registerTag: null == registerTag
          ? _value.registerTag
          : registerTag // ignore: cast_nullable_to_non_nullable
              as String,
      contextTags: null == contextTags
          ? _value._contextTags
          : contextTags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isPrimary: null == isPrimary
          ? _value.isPrimary
          : isPrimary // ignore: cast_nullable_to_non_nullable
              as bool,
      audioHash: freezed == audioHash
          ? _value.audioHash
          : audioHash // ignore: cast_nullable_to_non_nullable
              as String?,
      audioVoiceId: freezed == audioVoiceId
          ? _value.audioVoiceId
          : audioVoiceId // ignore: cast_nullable_to_non_nullable
              as String?,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      isSynced: null == isSynced
          ? _value.isSynced
          : isSynced // ignore: cast_nullable_to_non_nullable
              as bool,
      isDeleted: null == isDeleted
          ? _value.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WordVariantImpl implements _WordVariant {
  const _$WordVariantImpl(
      {required this.id,
      required this.conceptId,
      required this.word,
      required this.langCode,
      this.registerTag = 'neutral',
      final List<String> contextTags = const [],
      this.isPrimary = false,
      this.audioHash,
      this.audioVoiceId,
      this.position = 0,
      this.isSynced = false,
      this.isDeleted = false,
      required this.createdAt,
      required this.updatedAt})
      : _contextTags = contextTags;

  factory _$WordVariantImpl.fromJson(Map<String, dynamic> json) =>
      _$$WordVariantImplFromJson(json);

  @override
  final String id;
  @override
  final String conceptId;
  @override
  final String word;
  @override
  final String langCode;
  @override
  @JsonKey()
  final String registerTag;
  final List<String> _contextTags;
  @override
  @JsonKey()
  List<String> get contextTags {
    if (_contextTags is EqualUnmodifiableListView) return _contextTags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_contextTags);
  }

  @override
  @JsonKey()
  final bool isPrimary;
  @override
  final String? audioHash;
  @override
  final String? audioVoiceId;
  @override
  @JsonKey()
  final int position;
  @override
  @JsonKey()
  final bool isSynced;
  @override
  @JsonKey()
  final bool isDeleted;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'WordVariant(id: $id, conceptId: $conceptId, word: $word, langCode: $langCode, registerTag: $registerTag, contextTags: $contextTags, isPrimary: $isPrimary, audioHash: $audioHash, audioVoiceId: $audioVoiceId, position: $position, isSynced: $isSynced, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WordVariantImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.conceptId, conceptId) ||
                other.conceptId == conceptId) &&
            (identical(other.word, word) || other.word == word) &&
            (identical(other.langCode, langCode) ||
                other.langCode == langCode) &&
            (identical(other.registerTag, registerTag) ||
                other.registerTag == registerTag) &&
            const DeepCollectionEquality()
                .equals(other._contextTags, _contextTags) &&
            (identical(other.isPrimary, isPrimary) ||
                other.isPrimary == isPrimary) &&
            (identical(other.audioHash, audioHash) ||
                other.audioHash == audioHash) &&
            (identical(other.audioVoiceId, audioVoiceId) ||
                other.audioVoiceId == audioVoiceId) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.isSynced, isSynced) ||
                other.isSynced == isSynced) &&
            (identical(other.isDeleted, isDeleted) ||
                other.isDeleted == isDeleted) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      conceptId,
      word,
      langCode,
      registerTag,
      const DeepCollectionEquality().hash(_contextTags),
      isPrimary,
      audioHash,
      audioVoiceId,
      position,
      isSynced,
      isDeleted,
      createdAt,
      updatedAt);

  /// Create a copy of WordVariant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WordVariantImplCopyWith<_$WordVariantImpl> get copyWith =>
      __$$WordVariantImplCopyWithImpl<_$WordVariantImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WordVariantImplToJson(
      this,
    );
  }
}

abstract class _WordVariant implements WordVariant {
  const factory _WordVariant(
      {required final String id,
      required final String conceptId,
      required final String word,
      required final String langCode,
      final String registerTag,
      final List<String> contextTags,
      final bool isPrimary,
      final String? audioHash,
      final String? audioVoiceId,
      final int position,
      final bool isSynced,
      final bool isDeleted,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$WordVariantImpl;

  factory _WordVariant.fromJson(Map<String, dynamic> json) =
      _$WordVariantImpl.fromJson;

  @override
  String get id;
  @override
  String get conceptId;
  @override
  String get word;
  @override
  String get langCode;
  @override
  String get registerTag;
  @override
  List<String> get contextTags;
  @override
  bool get isPrimary;
  @override
  String? get audioHash;
  @override
  String? get audioVoiceId;
  @override
  int get position;
  @override
  bool get isSynced;
  @override
  bool get isDeleted;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of WordVariant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WordVariantImplCopyWith<_$WordVariantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
