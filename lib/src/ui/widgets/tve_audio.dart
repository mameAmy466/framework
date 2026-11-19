import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Ce qui est en cours de lecture audio.
class TveNowPlaying {
  final String id;
  final String title;
  final String? subtitle;
  final String? artwork;
  final bool isLive;
  const TveNowPlaying({required this.id, required this.title, this.subtitle, this.artwork, this.isLive = false});
}

/// Lecteur audio global (radio + podcasts) : continue quand on change d'onglet.
///
/// ```dart
/// TveAudioController.instance.play(url: p.url, item: TveNowPlaying(id: slug, title: 'Leral FM', isLive: true));
/// ```
class TveAudioController extends ChangeNotifier {
  TveAudioController._() {
    _sub = _player.playerStateStream.listen((_) => notifyListeners());
  }

  static final TveAudioController instance = TveAudioController._();

  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _sub;
  TveNowPlaying? _current;
  Object? error;

  TveNowPlaying? get current => _current;
  AudioPlayer get player => _player;
  bool get playing => _player.playing;
  bool get loading =>
      _player.processingState == ProcessingState.loading || _player.processingState == ProcessingState.buffering;

  bool isCurrent(String id) => _current?.id == id;

  Future<void> play({required String url, required TveNowPlaying item}) async {
    error = null;
    if (_current?.id == item.id && _player.audioSource != null) {
      await _player.play();
      return;
    }
    _current = item;
    notifyListeners();
    try {
      await _player.setUrl(url);
      unawaited(_player.play());
    } catch (e) {
      error = e;
      notifyListeners();
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> stop() async {
    await _player.stop();
    _current = null;
    notifyListeners();
  }

  /// Bascule lecture/pause pour [item] ; [resolveUrl] est appelé si on (re)démarre.
  Future<void> toggle(TveNowPlaying item, Future<String> Function() resolveUrl) async {
    if (isCurrent(item.id) && playing) return pause();
    if (isCurrent(item.id) && !item.isLive && _player.audioSource != null) return _player.play();
    try {
      final url = await resolveUrl();
      if (isCurrent(item.id)) _current = null; // live : URL fraîche
      await play(url: url, item: item);
    } catch (e) {
      error = e;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _player.dispose();
    super.dispose();
  }
}
