// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'variant_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

VariantProgress _$VariantProgressFromJson(Map<String, dynamic> json) {
  return _VariantProgress.fromJson(json);
}

/// @nodoc
mixin _$VariantProgress {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get variantId => throw _privateConstructorUsedError;
  QuizDirection get direction => throw _privateConstructorUsedError;
  double get stability => throw _privateConstructorUsedError;
  double get difficulty => throw _privateConstructorUsedError;
  int get elapsedDays => throw _privateConstructorUsedError;
  int get scheduledDays => throw _privateConstructorUsedError;
  int get reps => throw _privateConstructorUsedError;
  int get lapses => throw _privateConstructorUsedError;
  CardState get state => throw _privateConstructorUsedError;
  DateTime? get lastReview => throw _privateConstructorUsedError;
  DateTime? get nextReview => throw _privateConstructorUsedError;
  int get timesShown => throw _privateConstructorUsedError;
  int get timesCorrect => throw _privateConstructorUsedError;
  double get masteryLevel => throw _privateConstructorUsedError;
  bool get isSynced => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this VariantProgress to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VariantProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VariantProgressCopyWith<VariantProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VariantProgressCopyWith<$Res> {
  factory $VariantProgressCopyWith(
          VariantProgress value, $Res Function(VariantProgress) then) =
      _$VariantProgressCopyWithImpl<$Res, VariantProgress>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String variantId,
      QuizDirection direction,
      double stability,
      double difficulty,
      int elapsedDays,
      int scheduledDays,
      int reps,
      int lapses,
      CardState state,
      DateTime? lastReview,
      DateTime? nextReview,
      int timesShown,
      int timesCorrect,
      double masteryLevel,
      bool isSynced,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$VariantProgressCopyWithImpl<$Res, $Val extends VariantProgress>
    implements $VariantProgressCopyWith<$Res> {
  _$VariantProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VariantProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? variantId = null,
    Object? direction = null,
    Object? stability = null,
    Object? difficulty = null,
    Object? elapsedDays = null,
    Object? scheduledDays = null,
    Object? reps = null,
    Object? lapses = null,
    Object? state = null,
    Object? lastReview = freezed,
    Object? nextReview = freezed,
    Object? timesShown = null,
    Object? timesCorrect = null,
    Object? masteryLevel = null,
    Object? isSynced = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      variantId: null == variantId
          ? _value.variantId
          : variantId // ignore: cast_nullable_to_non_nullable
              as String,
      direction: null == direction
          ? _value.direction
          : direction // ignore: cast_nullable_to_non_nullable
              as QuizDirection,
      stability: null == stability
          ? _value.stability
          : stability // ignore: cast_nullable_to_non_nullable
              as double,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as double,
      elapsedDays: null == elapsedDays
          ? _value.elapsedDays
          : elapsedDays // ignore: cast_nullable_to_non_nullable
              as int,
      scheduledDays: null == scheduledDays
          ? _value.scheduledDays
          : scheduledDays // ignore: cast_nullable_to_non_nullable
              as int,
      reps: null == reps
          ? _value.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      lapses: null == lapses
          ? _value.lapses
          : lapses // ignore: cast_nullable_to_non_nullable
              as int,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as CardState,
      lastReview: freezed == lastReview
          ? _value.lastReview
          : lastReview // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      nextReview: freezed == nextReview
          ? _value.nextReview
          : nextReview // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      timesShown: null == timesShown
          ? _value.timesShown
          : timesShown // ignore: cast_nullable_to_non_nullable
              as int,
      timesCorrect: null == timesCorrect
          ? _value.timesCorrect
          : timesCorrect // ignore: cast_nullable_to_non_nullable
              as int,
      masteryLevel: null == masteryLevel
          ? _value.masteryLevel
          : masteryLevel // ignore: cast_nullable_to_non_nullable
              as double,
      isSynced: null == isSynced
          ? _value.isSynced
          : isSynced // ignore: cast_nullable_to_non_nullable
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
abstract class _$$VariantProgressImplCopyWith<$Res>
    implements $VariantProgressCopyWith<$Res> {
  factory _$$VariantProgressImplCopyWith(_$VariantProgressImpl value,
          $Res Function(_$VariantProgressImpl) then) =
      __$$VariantProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String variantId,
      QuizDirection direction,
      double stability,
      double difficulty,
      int elapsedDays,
      int scheduledDays,
      int reps,
      int lapses,
      CardState state,
      DateTime? lastReview,
      DateTime? nextReview,
      int timesShown,
      int timesCorrect,
      double masteryLevel,
      bool isSynced,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$VariantProgressImplCopyWithImpl<$Res>
    extends _$VariantProgressCopyWithImpl<$Res, _$VariantProgressImpl>
    implements _$$VariantProgressImplCopyWith<$Res> {
  __$$VariantProgressImplCopyWithImpl(
      _$VariantProgressImpl _value, $Res Function(_$VariantProgressImpl) _then)
      : super(_value, _then);

  /// Create a copy of VariantProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? variantId = null,
    Object? direction = null,
    Object? stability = null,
    Object? difficulty = null,
    Object? elapsedDays = null,
    Object? scheduledDays = null,
    Object? reps = null,
    Object? lapses = null,
    Object? state = null,
    Object? lastReview = freezed,
    Object? nextReview = freezed,
    Object? timesShown = null,
    Object? timesCorrect = null,
    Object? masteryLevel = null,
    Object? isSynced = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$VariantProgressImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      variantId: null == variantId
          ? _value.variantId
          : variantId // ignore: cast_nullable_to_non_nullable
              as String,
      direction: null == direction
          ? _value.direction
          : direction // ignore: cast_nullable_to_non_nullable
              as QuizDirection,
      stability: null == stability
          ? _value.stability
          : stability // ignore: cast_nullable_to_non_nullable
              as double,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as double,
      elapsedDays: null == elapsedDays
          ? _value.elapsedDays
          : elapsedDays // ignore: cast_nullable_to_non_nullable
              as int,
      scheduledDays: null == scheduledDays
          ? _value.scheduledDays
          : scheduledDays // ignore: cast_nullable_to_non_nullable
              as int,
      reps: null == reps
          ? _value.reps
          : reps // ignore: cast_nullable_to_non_nullable
              as int,
      lapses: null == lapses
          ? _value.lapses
          : lapses // ignore: cast_nullable_to_non_nullable
              as int,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as CardState,
      lastReview: freezed == lastReview
          ? _value.lastReview
          : lastReview // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      nextReview: freezed == nextReview
          ? _value.nextReview
          : nextReview // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      timesShown: null == timesShown
          ? _value.timesShown
          : timesShown // ignore: cast_nullable_to_non_nullable
              as int,
      timesCorrect: null == timesCorrect
          ? _value.timesCorrect
          : timesCorrect // ignore: cast_nullable_to_non_nullable
              as int,
      masteryLevel: null == masteryLevel
          ? _value.masteryLevel
          : masteryLevel // ignore: cast_nullable_to_non_nullable
              as double,
      isSynced: null == isSynced
          ? _value.isSynced
          : isSynced // ignore: cast_nullable_to_non_nullable
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
class _$VariantProgressImpl implements _VariantProgress {
  const _$VariantProgressImpl(
      {required this.id,
      required this.userId,
      required this.variantId,
      required this.direction,
      this.stability = 0.0,
      this.difficulty = 5.0,
      this.elapsedDays = 0,
      this.scheduledDays = 0,
      this.reps = 0,
      this.lapses = 0,
      this.state = CardState.newCard,
      this.lastReview,
      this.nextReview,
      this.timesShown = 0,
      this.timesCorrect = 0,
      this.masteryLevel = 0.0,
      this.isSynced = false,
      required this.createdAt,
      required this.updatedAt});

  factory _$VariantProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$VariantProgressImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String variantId;
  @override
  final QuizDirection direction;
  @override
  @JsonKey()
  final double stability;
  @override
  @JsonKey()
  final double difficulty;
  @override
  @JsonKey()
  final int elapsedDays;
  @override
  @JsonKey()
  final int scheduledDays;
  @override
  @JsonKey()
  final int reps;
  @override
  @JsonKey()
  final int lapses;
  @override
  @JsonKey()
  final CardState state;
  @override
  final DateTime? lastReview;
  @override
  final DateTime? nextReview;
  @override
  @JsonKey()
  final int timesShown;
  @override
  @JsonKey()
  final int timesCorrect;
  @override
  @JsonKey()
  final double masteryLevel;
  @override
  @JsonKey()
  final bool isSynced;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'VariantProgress(id: $id, userId: $userId, variantId: $variantId, direction: $direction, stability: $stability, difficulty: $difficulty, elapsedDays: $elapsedDays, scheduledDays: $scheduledDays, reps: $reps, lapses: $lapses, state: $state, lastReview: $lastReview, nextReview: $nextReview, timesShown: $timesShown, timesCorrect: $timesCorrect, masteryLevel: $masteryLevel, isSynced: $isSynced, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VariantProgressImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.variantId, variantId) ||
                other.variantId == variantId) &&
            (identical(other.direction, direction) ||
                other.direction == direction) &&
            (identical(other.stability, stability) ||
                other.stability == stability) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.elapsedDays, elapsedDays) ||
                other.elapsedDays == elapsedDays) &&
            (identical(other.scheduledDays, scheduledDays) ||
                other.scheduledDays == scheduledDays) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.lapses, lapses) || other.lapses == lapses) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.lastReview, lastReview) ||
                other.lastReview == lastReview) &&
            (identical(other.nextReview, nextReview) ||
                other.nextReview == nextReview) &&
            (identical(other.timesShown, timesShown) ||
                other.timesShown == timesShown) &&
            (identical(other.timesCorrect, timesCorrect) ||
                other.timesCorrect == timesCorrect) &&
            (identical(other.masteryLevel, masteryLevel) ||
                other.masteryLevel == masteryLevel) &&
            (identical(other.isSynced, isSynced) ||
                other.isSynced == isSynced) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        userId,
        variantId,
        direction,
        stability,
        difficulty,
        elapsedDays,
        scheduledDays,
        reps,
        lapses,
        state,
        lastReview,
        nextReview,
        timesShown,
        timesCorrect,
        masteryLevel,
        isSynced,
        createdAt,
        updatedAt
      ]);

  /// Create a copy of VariantProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VariantProgressImplCopyWith<_$VariantProgressImpl> get copyWith =>
      __$$VariantProgressImplCopyWithImpl<_$VariantProgressImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VariantProgressImplToJson(
      this,
    );
  }
}

abstract class _VariantProgress implements VariantProgress {
  const factory _VariantProgress(
      {required final String id,
      required final String userId,
      required final String variantId,
      required final QuizDirection direction,
      final double stability,
      final double difficulty,
      final int elapsedDays,
      final int scheduledDays,
      final int reps,
      final int lapses,
      final CardState state,
      final DateTime? lastReview,
      final DateTime? nextReview,
      final int timesShown,
      final int timesCorrect,
      final double masteryLevel,
      final bool isSynced,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$VariantProgressImpl;

  factory _VariantProgress.fromJson(Map<String, dynamic> json) =
      _$VariantProgressImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get variantId;
  @override
  QuizDirection get direction;
  @override
  double get stability;
  @override
  double get difficulty;
  @override
  int get elapsedDays;
  @override
  int get scheduledDays;
  @override
  int get reps;
  @override
  int get lapses;
  @override
  CardState get state;
  @override
  DateTime? get lastReview;
  @override
  DateTime? get nextReview;
  @override
  int get timesShown;
  @override
  int get timesCorrect;
  @override
  double get masteryLevel;
  @override
  bool get isSynced;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of VariantProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VariantProgressImplCopyWith<_$VariantProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
