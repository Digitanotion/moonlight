// lib/features/live_viewer/domain/entities/error_types.dart
enum LiveViewerErrorType {
  accessRevoked, // 403 - "Access revoked for this livestream"
  streamNotActive, // 422 - "Livestream is not active"
  streamEnded, // Live ended by host
  removedByHost, // User was removed
  networkError, // Connection issues
  permissionDenied, // No permission to view
  ageRestricted, // Age restriction
  privateStream, // Private stream, not invited
  geoBlocked, // Geographic restriction
  technicalError, // Server/technical issues
}
