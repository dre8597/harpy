import 'dart:convert';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;

part 'video_player_provider.freezed.dart';

final videoPlayerProvider = StateNotifierProvider.autoDispose
    .family<VideoPlayerNotifier, VideoPlayerState, VideoPlayerArguments>(
  (ref, arguments) {
    final handler = ref.watch(videoPlayerHandlerProvider);

    final notifier = VideoPlayerNotifier(
      urls: arguments.urls,
      loop: arguments.loop,
      ref: ref,
      onInitialized: arguments.isVideo ? () => handler.act((notifier) => notifier.pause()) : null,
    );

    if (arguments.isVideo) {
      handler.add(notifier);
      ref.onDispose(() => handler.remove(notifier));
    }

    return notifier;
  },
);

class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  VideoPlayerNotifier({
    required BuiltMap<String, String> urls,
    required bool loop,
    required Ref ref,
    VoidCallback? onInitialized,
  })  : assert(urls.isNotEmpty),
        _onInitialized = onInitialized,
        _urls = urls,
        _loop = loop,
        _ref = ref,
        super(const VideoPlayerState.uninitialized()) {
    _quality = urls.keys.first;
  }

  final BuiltMap<String, String> _urls;
  final bool _loop;
  final VoidCallback? _onInitialized;
  final Ref _ref;

  late String _quality;
  VideoPlayerController? _controller;
  bool _isPreloaded = false;

  VideoPlayerController get controller => _controller!;

  void _controllerListener() {
    if (!mounted || _controller == null) return;

    WakelockPlus.toggle(enable: _controller!.value.isPlaying);

    if (!_controller!.value.isInitialized) {
      state = const VideoPlayerState.uninitialized();
    } else if (_controller!.value.hasError) {
      state = VideoPlayerState.error(_controller!.value.errorDescription!);
    } else {
      state = VideoPlayerState.data(
        quality: _quality,
        qualities: _urls,
        isBuffering: _controller!.value.isBuffering,
        isPlaying: _controller!.value.isPlaying,
        isMuted: _controller!.value.volume == 0,
        isFinished: _controller!.value.duration != Duration.zero &&
            _controller!.value.position >=
                _controller!.value.duration - const Duration(milliseconds: 800),
        position: _controller!.value.position,
        duration: _controller!.value.duration,
        isPreloaded: _isPreloaded,
      );
    }
  }

  Future<void> preload() async {
    if (!mounted || _isPreloaded) return;

    try {
      state = const VideoPlayerState.loading();
      final didUrl = Uri.parse(_urls[_quality]!);

      final response = await http.get(didUrl);

      if (response.statusCode == 200) {
        final videoUrlBytes = response.bodyBytes;
        final m3u8Data = utf8.decode(videoUrlBytes);

        // Check if this is an M3U8 playlist
        if (m3u8Data.trim().startsWith('#EXTM3U')) {
          // Parse the M3U8 playlist to extract stream URLs
          final regex = RegExp(r'^#EXT-X-STREAM-INF:.*?\n(.*?)$', multiLine: true);
          final matches = regex.allMatches(m3u8Data);

          String? streamUrl;
          if (matches.isNotEmpty) {
            // Get the stream URL for the selected quality
            streamUrl = matches.elementAt(0).group(1);

            if (streamUrl != null) {
              // Resolve relative URL against the base URL
              final baseUrl = didUrl;
              final fullStreamUrl = baseUrl.resolve(streamUrl).toString();

              _controller = VideoPlayerController.networkUrl(
                Uri.parse(fullStreamUrl),
                videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
              );
            }
          }

          if (streamUrl == null) {
            throw Exception('No valid stream URL found in M3U8 playlist');
          }
        } else {
          // Not an M3U8 playlist, treat as direct video URL
          final videoUrl = utf8.decode(videoUrlBytes);
          _controller = VideoPlayerController.networkUrl(
            Uri.parse(videoUrl),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        }
        if(_controller == null) {
          throw Exception('Failed to resolve video URL');
        }
        await _controller!.initialize();
        _controller!.addListener(_controllerListener);

        final startMuted = _ref.read(mediaPreferencesProvider).startVideoPlaybackMuted;
        await _controller!.setVolume(startMuted ? 0.0 : 1.0);
        await _controller!.setLooping(_loop);

        _isPreloaded = true;
        _controllerListener();
      } else {
        throw Exception('Failed to resolve video URL: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      logErrorHandler(e, stackTrace);
      state = VideoPlayerState.error(e.toString());
    }
  }

  Future<void> initialize() async {
    if (!mounted) return;

    if (!_isPreloaded) {
      await preload();
    }

    if (mounted && state is VideoPlayerStateData) {
      await togglePlayback();
      _onInitialized?.call();
    }
  }

  Future<void> togglePlayback() async {
    if (!mounted || _controller == null) return;
    return _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
  }

  Future<void> pause() async {
    if (!mounted || _controller == null) return;
    return _controller!.pause();
  }

  Future<void> toggleMute() async {
    if (!mounted || _controller == null) return;
    return _controller!.value.volume == 0 ? _controller!.setVolume(1) : _controller!.setVolume(0);
  }

  Future<void> forward() async {
    if (!mounted || _controller == null) return;
    final position = await _controller!.position;

    if (position != null) {
      return _controller!.seekTo(position + const Duration(seconds: 5));
    }
  }

  Future<void> rewind() async {
    if (!mounted || _controller == null) return;
    final position = await _controller!.position;

    if (position != null ) {
      return _controller!.seekTo(position - const Duration(seconds: 5));
    }
  }

  Future<void> changeQuality(String quality) async {
    if (mounted || _quality == quality || _controller == null) return;

    final url = _urls[quality];

    if (url != null) {
      final position = await _controller!.position;
      final volume = _controller!.value.volume;
      final isPlaying = _controller!.value.isPlaying;
      final isLooping = _controller!.value.isLooping;

      final oldController = _controller;
      oldController!.removeListener(_controllerListener);

      try {
        final controller = VideoPlayerController.networkUrl(Uri.dataFromString(url));

        _quality = quality;

        await controller.initialize().then((_) {
          if (!mounted) {
            controller.seekTo(position ?? Duration.zero);
          }
        }).then((_) {
          if (!mounted) {
            controller.setVolume(volume);
          }
        }).then((_) {
          if (!mounted) {
            isPlaying ? controller.play() : controller.pause();
          }
        }).then((_) {
          if (!mounted) {
            controller.setLooping(isLooping);
          }
        }).then((_) {
          if (!mounted) {
            controller.addListener(_controllerListener);
          }
        }).handleError((error, stackTrace) {
          if (!mounted) {
            logErrorHandler(error, stackTrace);
          }
        });

        if (!mounted) {
          _controller = controller;
        }

        await oldController.dispose().handleError(
              logErrorHandler,
            );
      } catch (e, stackTrace) {
        if (!mounted) {
          logErrorHandler(e, stackTrace);
        }
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller?.dispose();
    super.dispose();
  }
}

@freezed
class VideoPlayerState with _$VideoPlayerState {
  const factory VideoPlayerState.uninitialized() = VideoPlayerStateUninitialized;

  const factory VideoPlayerState.loading() = VideoPlayerStateLoading;

  const factory VideoPlayerState.error(String message) = VideoPlayerStateError;

  const factory VideoPlayerState.data({
    required String quality,
    required BuiltMap<String, String> qualities,
    required bool isBuffering,
    required bool isPlaying,
    required bool isMuted,
    required bool isFinished,
    required Duration position,
    required Duration duration,
    @Default(false) bool isPreloaded,
  }) = VideoPlayerStateData;
}
