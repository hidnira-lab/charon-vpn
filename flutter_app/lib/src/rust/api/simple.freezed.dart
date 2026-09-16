// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'simple.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CharonEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CharonEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CharonEvent()';
}


}

/// @nodoc
class $CharonEventCopyWith<$Res>  {
$CharonEventCopyWith(CharonEvent _, $Res Function(CharonEvent) __);
}


/// Adds pattern-matching-related methods to [CharonEvent].
extension CharonEventPatterns on CharonEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CharonEvent_XrayLog value)?  xrayLog,TResult Function( CharonEvent_TunnelLog value)?  tunnelLog,TResult Function( CharonEvent_TunnelStopped value)?  tunnelStopped,TResult Function( CharonEvent_XrayStopped value)?  xrayStopped,TResult Function( CharonEvent_Blocked value)?  blocked,TResult Function( CharonEvent_Reconnecting value)?  reconnecting,TResult Function( CharonEvent_Reconnected value)?  reconnected,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CharonEvent_XrayLog() when xrayLog != null:
return xrayLog(_that);case CharonEvent_TunnelLog() when tunnelLog != null:
return tunnelLog(_that);case CharonEvent_TunnelStopped() when tunnelStopped != null:
return tunnelStopped(_that);case CharonEvent_XrayStopped() when xrayStopped != null:
return xrayStopped(_that);case CharonEvent_Blocked() when blocked != null:
return blocked(_that);case CharonEvent_Reconnecting() when reconnecting != null:
return reconnecting(_that);case CharonEvent_Reconnected() when reconnected != null:
return reconnected(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CharonEvent_XrayLog value)  xrayLog,required TResult Function( CharonEvent_TunnelLog value)  tunnelLog,required TResult Function( CharonEvent_TunnelStopped value)  tunnelStopped,required TResult Function( CharonEvent_XrayStopped value)  xrayStopped,required TResult Function( CharonEvent_Blocked value)  blocked,required TResult Function( CharonEvent_Reconnecting value)  reconnecting,required TResult Function( CharonEvent_Reconnected value)  reconnected,}){
final _that = this;
switch (_that) {
case CharonEvent_XrayLog():
return xrayLog(_that);case CharonEvent_TunnelLog():
return tunnelLog(_that);case CharonEvent_TunnelStopped():
return tunnelStopped(_that);case CharonEvent_XrayStopped():
return xrayStopped(_that);case CharonEvent_Blocked():
return blocked(_that);case CharonEvent_Reconnecting():
return reconnecting(_that);case CharonEvent_Reconnected():
return reconnected(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CharonEvent_XrayLog value)?  xrayLog,TResult? Function( CharonEvent_TunnelLog value)?  tunnelLog,TResult? Function( CharonEvent_TunnelStopped value)?  tunnelStopped,TResult? Function( CharonEvent_XrayStopped value)?  xrayStopped,TResult? Function( CharonEvent_Blocked value)?  blocked,TResult? Function( CharonEvent_Reconnecting value)?  reconnecting,TResult? Function( CharonEvent_Reconnected value)?  reconnected,}){
final _that = this;
switch (_that) {
case CharonEvent_XrayLog() when xrayLog != null:
return xrayLog(_that);case CharonEvent_TunnelLog() when tunnelLog != null:
return tunnelLog(_that);case CharonEvent_TunnelStopped() when tunnelStopped != null:
return tunnelStopped(_that);case CharonEvent_XrayStopped() when xrayStopped != null:
return xrayStopped(_that);case CharonEvent_Blocked() when blocked != null:
return blocked(_that);case CharonEvent_Reconnecting() when reconnecting != null:
return reconnecting(_that);case CharonEvent_Reconnected() when reconnected != null:
return reconnected(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String field0)?  xrayLog,TResult Function( String field0)?  tunnelLog,TResult Function( bool ok,  String? message)?  tunnelStopped,TResult Function( int? code)?  xrayStopped,TResult Function()?  blocked,TResult Function()?  reconnecting,TResult Function()?  reconnected,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CharonEvent_XrayLog() when xrayLog != null:
return xrayLog(_that.field0);case CharonEvent_TunnelLog() when tunnelLog != null:
return tunnelLog(_that.field0);case CharonEvent_TunnelStopped() when tunnelStopped != null:
return tunnelStopped(_that.ok,_that.message);case CharonEvent_XrayStopped() when xrayStopped != null:
return xrayStopped(_that.code);case CharonEvent_Blocked() when blocked != null:
return blocked();case CharonEvent_Reconnecting() when reconnecting != null:
return reconnecting();case CharonEvent_Reconnected() when reconnected != null:
return reconnected();case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String field0)  xrayLog,required TResult Function( String field0)  tunnelLog,required TResult Function( bool ok,  String? message)  tunnelStopped,required TResult Function( int? code)  xrayStopped,required TResult Function()  blocked,required TResult Function()  reconnecting,required TResult Function()  reconnected,}) {final _that = this;
switch (_that) {
case CharonEvent_XrayLog():
return xrayLog(_that.field0);case CharonEvent_TunnelLog():
return tunnelLog(_that.field0);case CharonEvent_TunnelStopped():
return tunnelStopped(_that.ok,_that.message);case CharonEvent_XrayStopped():
return xrayStopped(_that.code);case CharonEvent_Blocked():
return blocked();case CharonEvent_Reconnecting():
return reconnecting();case CharonEvent_Reconnected():
return reconnected();}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String field0)?  xrayLog,TResult? Function( String field0)?  tunnelLog,TResult? Function( bool ok,  String? message)?  tunnelStopped,TResult? Function( int? code)?  xrayStopped,TResult? Function()?  blocked,TResult? Function()?  reconnecting,TResult? Function()?  reconnected,}) {final _that = this;
switch (_that) {
case CharonEvent_XrayLog() when xrayLog != null:
return xrayLog(_that.field0);case CharonEvent_TunnelLog() when tunnelLog != null:
return tunnelLog(_that.field0);case CharonEvent_TunnelStopped() when tunnelStopped != null:
return tunnelStopped(_that.ok,_that.message);case CharonEvent_XrayStopped() when xrayStopped != null:
return xrayStopped(_that.code);case CharonEvent_Blocked() when blocked != null:
return blocked();case CharonEvent_Reconnecting() when reconnecting != null:
return reconnecting();case CharonEvent_Reconnected() when reconnected != null:
return reconnected();case _:
  return null;

}
}

}

/// @nodoc


class CharonEvent_XrayLog extends CharonEvent {
  const CharonEvent_XrayLog(this.field0): super._();
  

 final  String field0;

/// Create a copy of CharonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CharonEvent_XrayLogCopyWith<CharonEvent_XrayLog> get copyWith => _$CharonEvent_XrayLogCopyWithImpl<CharonEvent_XrayLog>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CharonEvent_XrayLog&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'CharonEvent.xrayLog(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CharonEvent_XrayLogCopyWith<$Res> implements $CharonEventCopyWith<$Res> {
  factory $CharonEvent_XrayLogCopyWith(CharonEvent_XrayLog value, $Res Function(CharonEvent_XrayLog) _then) = _$CharonEvent_XrayLogCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CharonEvent_XrayLogCopyWithImpl<$Res>
    implements $CharonEvent_XrayLogCopyWith<$Res> {
  _$CharonEvent_XrayLogCopyWithImpl(this._self, this._then);

  final CharonEvent_XrayLog _self;
  final $Res Function(CharonEvent_XrayLog) _then;

/// Create a copy of CharonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CharonEvent_XrayLog(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CharonEvent_TunnelLog extends CharonEvent {
  const CharonEvent_TunnelLog(this.field0): super._();
  

 final  String field0;

/// Create a copy of CharonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CharonEvent_TunnelLogCopyWith<CharonEvent_TunnelLog> get copyWith => _$CharonEvent_TunnelLogCopyWithImpl<CharonEvent_TunnelLog>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CharonEvent_TunnelLog&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'CharonEvent.tunnelLog(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CharonEvent_TunnelLogCopyWith<$Res> implements $CharonEventCopyWith<$Res> {
  factory $CharonEvent_TunnelLogCopyWith(CharonEvent_TunnelLog value, $Res Function(CharonEvent_TunnelLog) _then) = _$CharonEvent_TunnelLogCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CharonEvent_TunnelLogCopyWithImpl<$Res>
    implements $CharonEvent_TunnelLogCopyWith<$Res> {
  _$CharonEvent_TunnelLogCopyWithImpl(this._self, this._then);

  final CharonEvent_TunnelLog _self;
  final $Res Function(CharonEvent_TunnelLog) _then;

/// Create a copy of CharonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CharonEvent_TunnelLog(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CharonEvent_TunnelStopped extends CharonEvent {
  const CharonEvent_TunnelStopped({required this.ok, this.message}): super._();
  

 final  bool ok;
 final  String? message;

/// Create a copy of CharonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CharonEvent_TunnelStoppedCopyWith<CharonEvent_TunnelStopped> get copyWith => _$CharonEvent_TunnelStoppedCopyWithImpl<CharonEvent_TunnelStopped>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CharonEvent_TunnelStopped&&(identical(other.ok, ok) || other.ok == ok)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,ok,message);
}

@override
String toString() {
    return 'CharonEvent.tunnelStopped(ok: $ok, message: $message)';
}


}

/// @nodoc
abstract mixin class $CharonEvent_TunnelStoppedCopyWith<$Res> implements $CharonEventCopyWith<$Res> {
  factory $CharonEvent_TunnelStoppedCopyWith(CharonEvent_TunnelStopped value, $Res Function(CharonEvent_TunnelStopped) _then) = _$CharonEvent_TunnelStoppedCopyWithImpl;
@useResult
$Res call({
 bool ok, String? message
});




}
/// @nodoc
class _$CharonEvent_TunnelStoppedCopyWithImpl<$Res>
    implements $CharonEvent_TunnelStoppedCopyWith<$Res> {
  _$CharonEvent_TunnelStoppedCopyWithImpl(this._self, this._then);

  final CharonEvent_TunnelStopped _self;
  final $Res Function(CharonEvent_TunnelStopped) _then;

/// Create a copy of CharonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ok = null,Object? message = freezed,}) {
  return _then(CharonEvent_TunnelStopped(
ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class CharonEvent_XrayStopped extends CharonEvent {
  const CharonEvent_XrayStopped({this.code}): super._();
  

 final  int? code;

/// Create a copy of CharonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CharonEvent_XrayStoppedCopyWith<CharonEvent_XrayStopped> get copyWith => _$CharonEvent_XrayStoppedCopyWithImpl<CharonEvent_XrayStopped>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CharonEvent_XrayStopped&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode {
    return Object.hash(runtimeType,code);
}

@override
String toString() {
    return 'CharonEvent.xrayStopped(code: $code)';
}


}

/// @nodoc
abstract mixin class $CharonEvent_XrayStoppedCopyWith<$Res> implements $CharonEventCopyWith<$Res> {
  factory $CharonEvent_XrayStoppedCopyWith(CharonEvent_XrayStopped value, $Res Function(CharonEvent_XrayStopped) _then) = _$CharonEvent_XrayStoppedCopyWithImpl;
@useResult
$Res call({
 int? code
});




}
/// @nodoc
class _$CharonEvent_XrayStoppedCopyWithImpl<$Res>
    implements $CharonEvent_XrayStoppedCopyWith<$Res> {
  _$CharonEvent_XrayStoppedCopyWithImpl(this._self, this._then);

  final CharonEvent_XrayStopped _self;
  final $Res Function(CharonEvent_XrayStopped) _then;

/// Create a copy of CharonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = freezed,}) {
  return _then(CharonEvent_XrayStopped(
code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc


class CharonEvent_Blocked extends CharonEvent {
  const CharonEvent_Blocked(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CharonEvent_Blocked);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CharonEvent.blocked()';
}


}




/// @nodoc


class CharonEvent_Reconnecting extends CharonEvent {
  const CharonEvent_Reconnecting(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CharonEvent_Reconnecting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CharonEvent.reconnecting()';
}


}




/// @nodoc


class CharonEvent_Reconnected extends CharonEvent {
  const CharonEvent_Reconnected(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CharonEvent_Reconnected);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CharonEvent.reconnected()';
}


}




// dart format on
