// Platform-aware export for Whisper service.
//
// - Web: uses a safe stub (no FFI imports).
// - IO platforms: uses whisper_kit-backed implementation.
export 'whisper_service_stub.dart'
    if (dart.library.io) 'whisper_service_io.dart';
