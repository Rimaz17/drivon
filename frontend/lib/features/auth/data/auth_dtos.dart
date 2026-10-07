import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/user.dart';

part 'auth_dtos.freezed.dart';
part 'auth_dtos.g.dart';

/// `UserResponse` from the API.
@freezed
abstract class UserDto with _$UserDto {
  const factory UserDto({
    required String id,
    required String name,
    required String email,
  }) = _UserDto;

  const UserDto._();

  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);

  factory UserDto.fromDomain(User user) =>
      UserDto(id: user.id, name: user.name, email: user.email);

  User toDomain() => User(id: id, name: name, email: email);
}

/// `AuthResponse` from register, login and refresh.
@freezed
abstract class AuthResponseDto with _$AuthResponseDto {
  const factory AuthResponseDto({
    required String accessToken,
    required String refreshToken,
    required UserDto user,
  }) = _AuthResponseDto;

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseDtoFromJson(json);
}
