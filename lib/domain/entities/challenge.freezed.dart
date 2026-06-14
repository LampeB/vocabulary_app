// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'challenge.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Challenge _$ChallengeFromJson(Map<String, dynamic> json) {
  return _Challenge.fromJson(json);
}

/// @nodoc
mixin _$Challenge {
  String get id => throw _privateConstructorUsedError;
  String get listId => throw _privateConstructorUsedError;
  String get listName => throw _privateConstructorUsedError;
  String get challengerId => throw _privateConstructorUsedError;
  String get challengedId => throw _privateConstructorUsedError;
  AppUserSummaryC get challenger => throw _privateConstructorUsedError;
  AppUserSummaryC get challenged => throw _privateConstructorUsedError;
  ChallengeStatus get status => throw _privateConstructorUsedError;
  int? get challengerScore => throw _privateConstructorUsedError;
  int? get challengedScore => throw _privateConstructorUsedError;
  int get wordCount => throw _privateConstructorUsedError;
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Challenge to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Challenge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChallengeCopyWith<Challenge> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChallengeCopyWith<$Res> {
  factory $ChallengeCopyWith(Challenge value, $Res Function(Challenge) then) =
      _$ChallengeCopyWithImpl<$Res, Challenge>;
  @useResult
  $Res call(
      {String id,
      String listId,
      String listName,
      String challengerId,
      String challengedId,
      AppUserSummaryC challenger,
      AppUserSummaryC challenged,
      ChallengeStatus status,
      int? challengerScore,
      int? challengedScore,
      int wordCount,
      DateTime? expiresAt,
      DateTime createdAt});

  $AppUserSummaryCCopyWith<$Res> get challenger;
  $AppUserSummaryCCopyWith<$Res> get challenged;
}

/// @nodoc
class _$ChallengeCopyWithImpl<$Res, $Val extends Challenge>
    implements $ChallengeCopyWith<$Res> {
  _$ChallengeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Challenge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? listId = null,
    Object? listName = null,
    Object? challengerId = null,
    Object? challengedId = null,
    Object? challenger = null,
    Object? challenged = null,
    Object? status = null,
    Object? challengerScore = freezed,
    Object? challengedScore = freezed,
    Object? wordCount = null,
    Object? expiresAt = freezed,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      listId: null == listId
          ? _value.listId
          : listId // ignore: cast_nullable_to_non_nullable
              as String,
      listName: null == listName
          ? _value.listName
          : listName // ignore: cast_nullable_to_non_nullable
              as String,
      challengerId: null == challengerId
          ? _value.challengerId
          : challengerId // ignore: cast_nullable_to_non_nullable
              as String,
      challengedId: null == challengedId
          ? _value.challengedId
          : challengedId // ignore: cast_nullable_to_non_nullable
              as String,
      challenger: null == challenger
          ? _value.challenger
          : challenger // ignore: cast_nullable_to_non_nullable
              as AppUserSummaryC,
      challenged: null == challenged
          ? _value.challenged
          : challenged // ignore: cast_nullable_to_non_nullable
              as AppUserSummaryC,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ChallengeStatus,
      challengerScore: freezed == challengerScore
          ? _value.challengerScore
          : challengerScore // ignore: cast_nullable_to_non_nullable
              as int?,
      challengedScore: freezed == challengedScore
          ? _value.challengedScore
          : challengedScore // ignore: cast_nullable_to_non_nullable
              as int?,
      wordCount: null == wordCount
          ? _value.wordCount
          : wordCount // ignore: cast_nullable_to_non_nullable
              as int,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }

  /// Create a copy of Challenge
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AppUserSummaryCCopyWith<$Res> get challenger {
    return $AppUserSummaryCCopyWith<$Res>(_value.challenger, (value) {
      return _then(_value.copyWith(challenger: value) as $Val);
    });
  }

  /// Create a copy of Challenge
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AppUserSummaryCCopyWith<$Res> get challenged {
    return $AppUserSummaryCCopyWith<$Res>(_value.challenged, (value) {
      return _then(_value.copyWith(challenged: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ChallengeImplCopyWith<$Res>
    implements $ChallengeCopyWith<$Res> {
  factory _$$ChallengeImplCopyWith(
          _$ChallengeImpl value, $Res Function(_$ChallengeImpl) then) =
      __$$ChallengeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String listId,
      String listName,
      String challengerId,
      String challengedId,
      AppUserSummaryC challenger,
      AppUserSummaryC challenged,
      ChallengeStatus status,
      int? challengerScore,
      int? challengedScore,
      int wordCount,
      DateTime? expiresAt,
      DateTime createdAt});

  @override
  $AppUserSummaryCCopyWith<$Res> get challenger;
  @override
  $AppUserSummaryCCopyWith<$Res> get challenged;
}

/// @nodoc
class __$$ChallengeImplCopyWithImpl<$Res>
    extends _$ChallengeCopyWithImpl<$Res, _$ChallengeImpl>
    implements _$$ChallengeImplCopyWith<$Res> {
  __$$ChallengeImplCopyWithImpl(
      _$ChallengeImpl _value, $Res Function(_$ChallengeImpl) _then)
      : super(_value, _then);

  /// Create a copy of Challenge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? listId = null,
    Object? listName = null,
    Object? challengerId = null,
    Object? challengedId = null,
    Object? challenger = null,
    Object? challenged = null,
    Object? status = null,
    Object? challengerScore = freezed,
    Object? challengedScore = freezed,
    Object? wordCount = null,
    Object? expiresAt = freezed,
    Object? createdAt = null,
  }) {
    return _then(_$ChallengeImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      listId: null == listId
          ? _value.listId
          : listId // ignore: cast_nullable_to_non_nullable
              as String,
      listName: null == listName
          ? _value.listName
          : listName // ignore: cast_nullable_to_non_nullable
              as String,
      challengerId: null == challengerId
          ? _value.challengerId
          : challengerId // ignore: cast_nullable_to_non_nullable
              as String,
      challengedId: null == challengedId
          ? _value.challengedId
          : challengedId // ignore: cast_nullable_to_non_nullable
              as String,
      challenger: null == challenger
          ? _value.challenger
          : challenger // ignore: cast_nullable_to_non_nullable
              as AppUserSummaryC,
      challenged: null == challenged
          ? _value.challenged
          : challenged // ignore: cast_nullable_to_non_nullable
              as AppUserSummaryC,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ChallengeStatus,
      challengerScore: freezed == challengerScore
          ? _value.challengerScore
          : challengerScore // ignore: cast_nullable_to_non_nullable
              as int?,
      challengedScore: freezed == challengedScore
          ? _value.challengedScore
          : challengedScore // ignore: cast_nullable_to_non_nullable
              as int?,
      wordCount: null == wordCount
          ? _value.wordCount
          : wordCount // ignore: cast_nullable_to_non_nullable
              as int,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChallengeImpl implements _Challenge {
  const _$ChallengeImpl(
      {required this.id,
      required this.listId,
      required this.listName,
      required this.challengerId,
      required this.challengedId,
      required this.challenger,
      required this.challenged,
      this.status = ChallengeStatus.pending,
      this.challengerScore,
      this.challengedScore,
      this.wordCount = 0,
      this.expiresAt,
      required this.createdAt});

  factory _$ChallengeImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChallengeImplFromJson(json);

  @override
  final String id;
  @override
  final String listId;
  @override
  final String listName;
  @override
  final String challengerId;
  @override
  final String challengedId;
  @override
  final AppUserSummaryC challenger;
  @override
  final AppUserSummaryC challenged;
  @override
  @JsonKey()
  final ChallengeStatus status;
  @override
  final int? challengerScore;
  @override
  final int? challengedScore;
  @override
  @JsonKey()
  final int wordCount;
  @override
  final DateTime? expiresAt;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Challenge(id: $id, listId: $listId, listName: $listName, challengerId: $challengerId, challengedId: $challengedId, challenger: $challenger, challenged: $challenged, status: $status, challengerScore: $challengerScore, challengedScore: $challengedScore, wordCount: $wordCount, expiresAt: $expiresAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChallengeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.listId, listId) || other.listId == listId) &&
            (identical(other.listName, listName) ||
                other.listName == listName) &&
            (identical(other.challengerId, challengerId) ||
                other.challengerId == challengerId) &&
            (identical(other.challengedId, challengedId) ||
                other.challengedId == challengedId) &&
            (identical(other.challenger, challenger) ||
                other.challenger == challenger) &&
            (identical(other.challenged, challenged) ||
                other.challenged == challenged) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.challengerScore, challengerScore) ||
                other.challengerScore == challengerScore) &&
            (identical(other.challengedScore, challengedScore) ||
                other.challengedScore == challengedScore) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      listId,
      listName,
      challengerId,
      challengedId,
      challenger,
      challenged,
      status,
      challengerScore,
      challengedScore,
      wordCount,
      expiresAt,
      createdAt);

  /// Create a copy of Challenge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChallengeImplCopyWith<_$ChallengeImpl> get copyWith =>
      __$$ChallengeImplCopyWithImpl<_$ChallengeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChallengeImplToJson(
      this,
    );
  }
}

abstract class _Challenge implements Challenge {
  const factory _Challenge(
      {required final String id,
      required final String listId,
      required final String listName,
      required final String challengerId,
      required final String challengedId,
      required final AppUserSummaryC challenger,
      required final AppUserSummaryC challenged,
      final ChallengeStatus status,
      final int? challengerScore,
      final int? challengedScore,
      final int wordCount,
      final DateTime? expiresAt,
      required final DateTime createdAt}) = _$ChallengeImpl;

  factory _Challenge.fromJson(Map<String, dynamic> json) =
      _$ChallengeImpl.fromJson;

  @override
  String get id;
  @override
  String get listId;
  @override
  String get listName;
  @override
  String get challengerId;
  @override
  String get challengedId;
  @override
  AppUserSummaryC get challenger;
  @override
  AppUserSummaryC get challenged;
  @override
  ChallengeStatus get status;
  @override
  int? get challengerScore;
  @override
  int? get challengedScore;
  @override
  int get wordCount;
  @override
  DateTime? get expiresAt;
  @override
  DateTime get createdAt;

  /// Create a copy of Challenge
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChallengeImplCopyWith<_$ChallengeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AppUserSummaryC _$AppUserSummaryCFromJson(Map<String, dynamic> json) {
  return _AppUserSummaryC.fromJson(json);
}

/// @nodoc
mixin _$AppUserSummaryC {
  String get id => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;

  /// Serializes this AppUserSummaryC to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppUserSummaryC
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppUserSummaryCCopyWith<AppUserSummaryC> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUserSummaryCCopyWith<$Res> {
  factory $AppUserSummaryCCopyWith(
          AppUserSummaryC value, $Res Function(AppUserSummaryC) then) =
      _$AppUserSummaryCCopyWithImpl<$Res, AppUserSummaryC>;
  @useResult
  $Res call({String id, String username, String? avatarUrl});
}

/// @nodoc
class _$AppUserSummaryCCopyWithImpl<$Res, $Val extends AppUserSummaryC>
    implements $AppUserSummaryCCopyWith<$Res> {
  _$AppUserSummaryCCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppUserSummaryC
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? avatarUrl = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AppUserSummaryCImplCopyWith<$Res>
    implements $AppUserSummaryCCopyWith<$Res> {
  factory _$$AppUserSummaryCImplCopyWith(_$AppUserSummaryCImpl value,
          $Res Function(_$AppUserSummaryCImpl) then) =
      __$$AppUserSummaryCImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String username, String? avatarUrl});
}

/// @nodoc
class __$$AppUserSummaryCImplCopyWithImpl<$Res>
    extends _$AppUserSummaryCCopyWithImpl<$Res, _$AppUserSummaryCImpl>
    implements _$$AppUserSummaryCImplCopyWith<$Res> {
  __$$AppUserSummaryCImplCopyWithImpl(
      _$AppUserSummaryCImpl _value, $Res Function(_$AppUserSummaryCImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppUserSummaryC
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? avatarUrl = freezed,
  }) {
    return _then(_$AppUserSummaryCImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AppUserSummaryCImpl implements _AppUserSummaryC {
  const _$AppUserSummaryCImpl(
      {required this.id, required this.username, this.avatarUrl});

  factory _$AppUserSummaryCImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppUserSummaryCImplFromJson(json);

  @override
  final String id;
  @override
  final String username;
  @override
  final String? avatarUrl;

  @override
  String toString() {
    return 'AppUserSummaryC(id: $id, username: $username, avatarUrl: $avatarUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppUserSummaryCImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, username, avatarUrl);

  /// Create a copy of AppUserSummaryC
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppUserSummaryCImplCopyWith<_$AppUserSummaryCImpl> get copyWith =>
      __$$AppUserSummaryCImplCopyWithImpl<_$AppUserSummaryCImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppUserSummaryCImplToJson(
      this,
    );
  }
}

abstract class _AppUserSummaryC implements AppUserSummaryC {
  const factory _AppUserSummaryC(
      {required final String id,
      required final String username,
      final String? avatarUrl}) = _$AppUserSummaryCImpl;

  factory _AppUserSummaryC.fromJson(Map<String, dynamic> json) =
      _$AppUserSummaryCImpl.fromJson;

  @override
  String get id;
  @override
  String get username;
  @override
  String? get avatarUrl;

  /// Create a copy of AppUserSummaryC
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppUserSummaryCImplCopyWith<_$AppUserSummaryCImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
