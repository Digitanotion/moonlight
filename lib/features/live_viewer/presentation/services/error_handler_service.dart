// lib/features/live_viewer/presentation/services/error_handler_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/features/live_viewer/domain/entities/error_types.dart';

class LiveViewerErrorHandler {
  static LiveViewerErrorType parseDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final message = error.response?.data?['message']?.toString().toLowerCase();

    if (statusCode == 403) {
      if (message?.contains('access revoked') == true ||
          message?.contains('not authorized') == true) {
        return LiveViewerErrorType.accessRevoked;
      }
      if (message?.contains('permission') == true) {
        return LiveViewerErrorType.permissionDenied;
      }
      if (message?.contains('age') == true ||
          message?.contains('restricted') == true) {
        return LiveViewerErrorType.ageRestricted;
      }
      return LiveViewerErrorType.permissionDenied;
    }

    if (statusCode == 422) {
      if (message?.contains('not active') == true ||
          message?.contains('ended') == true) {
        return LiveViewerErrorType.streamNotActive;
      }
    }

    if (statusCode == 404) {
      return LiveViewerErrorType.streamNotActive;
    }

    if (statusCode == 429) {
      return LiveViewerErrorType.technicalError;
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return LiveViewerErrorType.networkError;
    }

    return LiveViewerErrorType.technicalError;
  }

  static String getErrorMessage(DioException error) {
    return error.response?.data?['message']?.toString() ??
        error.message ??
        'An unexpected error occurred';
  }

  static bool shouldAllowRetry(LiveViewerErrorType errorType) {
    return errorType == LiveViewerErrorType.networkError ||
        errorType == LiveViewerErrorType.technicalError;
  }

  static bool shouldShowImmediately(LiveViewerErrorType errorType) {
    // These errors should block the UI immediately
    return errorType == LiveViewerErrorType.accessRevoked ||
        errorType == LiveViewerErrorType.streamNotActive ||
        errorType == LiveViewerErrorType.permissionDenied ||
        errorType == LiveViewerErrorType.ageRestricted ||
        errorType == LiveViewerErrorType.privateStream ||
        errorType == LiveViewerErrorType.geoBlocked;
  }
}
