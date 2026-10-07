import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

/// The signed-in account.
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String email,
  }) = _User;

  const User._();

  /// First word of the name, for greetings.
  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}
