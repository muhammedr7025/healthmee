import 'package:dio/dio.dart';

/// Turns a failed auth call into something a person can act on. The backend
/// already sends precise answers (409 for a taken email, 401 for a bad
/// password) — collapsing all of them into one generic line was the
/// complaint: "it didn't say the account already exists."
String authErrorMessage(Object error, {required String fallback}) {
  if (error is DioException) {
    switch (error.response?.statusCode) {
      case 409:
        return 'That email already has an account.';
      case 401:
        return "That email and password don't match.";
      case 422:
        return 'Check the email address, and use at least 8 characters for the password.';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return "Can't reach the server — check your connection and try again.";
      default:
        break;
    }
  }
  return fallback;
}

bool isEmailTakenError(Object error) => error is DioException && error.response?.statusCode == 409;
