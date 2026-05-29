// lib/services/user_api_service.dart
  // Dio-based REST client for the User endpoint.
  // Handles serialization, timeouts, and typed error translation.
  // Does NOT contain business logic — only network I/O.

  import 'package:dio/dio.dart';
  import 'package:flutter/foundation.dart';
  import '../models/app_models.dart';

  // ─── DTO ──────────────────────────────────────────────────────
  // Maps between the server JSON shape and AppUser.
  // Password is never returned by server; it is only sent on
  // create/password-change requests.

  class UserDto {
    final String id;
    final String login;
    final String firstName;
    final String lastName;
    final String organization;
    final String email;
    final String phone;

    const UserDto({
      required this.id,
      required this.login,
      required this.firstName,
      required this.lastName,
      required this.organization,
      required this.email,
      this.phone = '',
    });

    factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
          id:           (json['id']           as String?) ?? '',
          login:        (json['login']        as String?) ?? '',
          firstName:    (json['firstName']    as String?) ?? '',
          lastName:     (json['lastName']     as String?) ?? '',
          organization: (json['organization'] as String?) ?? '',
          email:        (json['email']        as String?) ?? '',
          phone:        (json['phone']        as String?) ?? '',
        );

    Map<String, dynamic> toJson() => {
          'id':           id,
          'login':        login,
          'firstName':    firstName,
          'lastName':     lastName,
          'organization': organization,
          'email':        email,
          'phone':        phone,
        };
  
    // Converts to AppUser, preserving the local passwordHash (not stored on server).
    AppUser toAppUser({String passwordHash = ''}) => AppUser(
          id:           id,
          login:        login,
          firstName:    firstName,
          lastName:     lastName,
          organization: organization,
          email:        email,
          phone:        phone,
          passwordHash: passwordHash,
        );

    factory UserDto.fromAppUser(AppUser u) => UserDto(
          id:           u.id,
          login:        u.login,
          firstName:    u.firstName,
          lastName:     u.lastName,
          organization: u.organization,
          email:        u.email,
          phone:        u.phone,
        );
  }

  // ─── ApiException ─────────────────────────────────────────────

  class ApiException implements Exception {
    final int? statusCode;
    final String message;
    const ApiException({this.statusCode, required this.message});

    @override
    String toString() => 'ApiException($statusCode): $message';
  }
  
  // ─── UserApiService ───────────────────────────────────────────

  class UserApiService {
    static const _baseUrl        = 'http://localhost:3000';
    static const _connectTimeout = Duration(seconds: 10);
    static const _receiveTimeout = Duration(seconds: 10);

    late final Dio _dio;

    UserApiService() {
      _dio = Dio(
        BaseOptions(
          baseUrl:        _baseUrl,
          connectTimeout: _connectTimeout,
          receiveTimeout: _receiveTimeout,
          headers: {'Content-Type': 'application/json'},
        ),
      );
    }

    @visibleForTesting
    UserApiService.withDio(Dio dio) {
      _dio = dio;
    }

    // ── GET /user ─────────────────────────────────────────────
    // Fetches the user from server. Passes the user id as a query
    // parameter so the server can identify which user to return.
    // Returns null on 404 (user not yet synced to server).

    Future<UserDto?> getUser({String? id}) async {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/user',
          queryParameters: id != null ? {'id': id} : null,
        );
        if (response.data == null) return null;
        return UserDto.fromJson(response.data!);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) return null;
        throw _convert(e);
      }
    }

    // ── POST /user ────────────────────────────────────────────
    // Creates user on server during registration.
    // Password is included in the request body; never returned.

    Future<UserDto?> createUser(UserDto dto, String password) async {
      try {
        final body = dto.toJson()..['password'] = password;
        final response = await _dio.post<Map<String, dynamic>>('/user', data: body);
        if (response.data == null) return null;
        return UserDto.fromJson(response.data!);
      } on DioException catch (e) {
        throw _convert(e);
      }
    }

    // ── PUT /user ─────────────────────────────────────────────
    // Full profile update. Server responds with updated user or 204.

    Future<UserDto?> updateUser(UserDto dto) async {
      try {
        final response = await _dio.put<Map<String, dynamic>>('/user', data: dto.toJson());
        if (response.data == null) return dto; // 204 No Content → keep local
        return UserDto.fromJson(response.data!);
      } on DioException catch (e) {
        throw _convert(e);
      }
    }

    // ── PATCH /user ───────────────────────────────────────────
    // Password-only update. Does not change other profile fields.

    Future<void> updatePassword({
      required String login,
      required String currentPassword,
      required String newPassword,
    }) async {
      try {
        await _dio.patch<void>('/user', data: {
          'login':           login,
          'currentPassword': currentPassword,
          'newPassword':     newPassword,
        });
      } on DioException catch (e) {
        throw _convert(e);
      }
    }

    // ── Error translation ─────────────────────────────────────

    ApiException _convert(DioException e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const ApiException(message: 'Превышено время ожидания сервера');
        case DioExceptionType.connectionError:
          return const ApiException(message: 'Нет соединения с сервером');
        default:
          break;
      }
      final code = e.response?.statusCode;
      final body = e.response?.data;
      final serverMsg = body is Map ? (body['message'] as String?) ?? '' : '';
      return ApiException(
        statusCode: code,
        message: serverMsg.isNotEmpty ? serverMsg : 'Ошибка сервера ($code)',
      );
    }
  }
