import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_service.dart';

const _kDisabled = 'marketcatia_music_disabled';
const _kMuted = 'marketcatia_music_muted';
const _kIndex = 'marketcatia_music_index';
const _volume = 0.28;

/// Pistas empaquetadas (mismo set que la web).
const kMusicTracks = <String>[
  'assets/music/1.mp3',
  'assets/music/2.mp3',
  'assets/music/3.mp3',
];

/// Música de fondo: flag remoto + prefs locales + playlist secuencial.
class BackgroundMusicController extends ChangeNotifier {
  BackgroundMusicController({FirebaseService? firebase})
      : _firebase = firebase ?? FirebaseService();

  final FirebaseService _firebase;
  final AudioPlayer _player = AudioPlayer();

  bool settingsReady = false;
  bool remoteEnabled = true;
  bool disabled = false;
  bool muted = false;
  bool needsGesture = false;
  bool isPlaying = false;
  int trackIndex = 0;

  bool get hasTracks => kMusicTracks.isNotEmpty;
  bool get musicAllowed =>
      settingsReady && remoteEnabled && hasTracks && !disabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    disabled = prefs.getBool(_kDisabled) ?? false;
    muted = prefs.getBool(_kMuted) ?? false;
    trackIndex = prefs.getInt(_kIndex) ?? 0;
    if (trackIndex < 0 || trackIndex >= kMusicTracks.length) trackIndex = 0;

    if (Firebase.apps.isNotEmpty) {
      remoteEnabled = await _firebase.fetchBackgroundMusicEnabled();
    } else {
      remoteEnabled = true;
    }
    settingsReady = true;
    notifyListeners();

    if (!remoteEnabled || !hasTracks) return;

    await _player.setVolume(_volume);
    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      if (isPlaying != playing) {
        isPlaying = playing;
        notifyListeners();
      }
      if (state.processingState == ProcessingState.completed) {
        next(auto: true);
      }
    });

    if (!disabled) {
      await _loadCurrent(autoplay: true);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDisabled, disabled);
    await prefs.setBool(_kMuted, muted);
    await prefs.setInt(_kIndex, trackIndex);
  }

  Future<void> _loadCurrent({required bool autoplay}) async {
    if (!hasTracks) return;
    try {
      await _player.setAsset(kMusicTracks[trackIndex]);
      await _player.setVolume(muted || needsGesture ? 0 : _volume);
      if (autoplay && !disabled) {
        try {
          await _player.play();
          needsGesture = false;
        } catch (_) {
          // iOS/Android autoplay bloqueado → pedir gesto.
          needsGesture = true;
          isPlaying = false;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('music load error: $e');
    }
    notifyListeners();
  }

  Future<void> tryPlay() async {
    if (!musicAllowed) return;
    needsGesture = false;
    await _player.setVolume(muted ? 0 : _volume);
    try {
      await _player.play();
    } catch (_) {
      needsGesture = true;
    }
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (!musicAllowed) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      await tryPlay();
    }
    notifyListeners();
  }

  Future<void> next({bool auto = false}) async {
    if (!hasTracks) return;
    trackIndex = (trackIndex + 1) % kMusicTracks.length;
    await _persist();
    await _loadCurrent(autoplay: auto || _player.playing || !needsGesture);
  }

  Future<void> prev() async {
    if (!hasTracks) return;
    trackIndex = (trackIndex - 1 + kMusicTracks.length) % kMusicTracks.length;
    await _persist();
    await _loadCurrent(autoplay: _player.playing || !needsGesture);
  }

  Future<void> toggleMute() async {
    muted = !muted;
    await _player.setVolume(muted || needsGesture ? 0 : _volume);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleDisabled() async {
    disabled = !disabled;
    await _persist();
    if (disabled) {
      await _player.pause();
      isPlaying = false;
    } else if (remoteEnabled) {
      await _loadCurrent(autoplay: true);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
