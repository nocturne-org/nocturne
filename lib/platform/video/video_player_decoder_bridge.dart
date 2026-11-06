import 'dart:async';

/// Schnittstelle fuer den Hardware-Videodecoder (entkoppelt fuer Unit-Tests und Mocking).
abstract class VideoDecoderBridge {
  /// Allokiert den Videodecoder und laedt den Stream.
  Future<void> initialize(String videoUrl, {Duration? initialPosition});

  /// Startet die Videowiedergabe.
  Future<void> play();

  /// Pausiert das Video.
  Future<void> pause();

  /// Springt an eine bestimmte Zeitposition.
  Future<void> seek(Duration position);

  /// Gibt saemtliche Hardware-Decoder-Ressourcen vollstaendig frei (0 GPU-Last).
  Future<void> release();

  /// Aktuelle Wiedergabeposition des Videodecoders.
  Stream<Duration> get positionStream;

  /// Ob der Videodecoder aktuell allokiert ist.
  bool get isAllocated;
}

/// Standard-Implementierung fuer Video-Decoder Lifecycle Management.
class DefaultVideoDecoderBridge implements VideoDecoderBridge {
  final StreamController<Duration> _posCtrl = StreamController<Duration>.broadcast();
  bool _allocated = false;
  Duration _currentPos = Duration.zero;

  @override
  bool get isAllocated => _allocated;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Future<void> initialize(String videoUrl, {Duration? initialPosition}) async {
    _allocated = true;
    _currentPos = initialPosition ?? Duration.zero;
    _posCtrl.add(_currentPos);
  }

  @override
  Future<void> play() async {
    if (!_allocated) return;
  }

  @override
  Future<void> pause() async {
    if (!_allocated) return;
  }

  @override
  Future<void> seek(Duration position) async {
    _currentPos = position;
    _posCtrl.add(_currentPos);
  }

  @override
  Future<void> release() async {
    _allocated = false;
    _currentPos = Duration.zero;
  }

  Future<void> dispose() async {
    await release();
    await _posCtrl.close();
  }
}
