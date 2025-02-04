import 'package:bluesky/app_bsky_embed_video.dart' show EmbedVideoView;
import 'package:bluesky/bluesky.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'embed_view_provider.freezed.dart';

final embedViewProvider = NotifierProvider.autoDispose
    .family<EmbedViewNotifier, EmbedViewState, EmbedView>(
  EmbedViewNotifier.new,
);

@freezed
class EmbedViewState with _$EmbedViewState {
  const factory EmbedViewState.initial() = _Initial;

  const factory EmbedViewState.loading() = _Loading;

  const factory EmbedViewState.error(String message) = _Error;

  const factory EmbedViewState.record({
    required EmbedViewRecord data,
  }) = _Record;

  const factory EmbedViewState.images({
    required EmbedViewImages data,
  }) = _Images;

  const factory EmbedViewState.external({
    required EmbedViewExternal data,
  }) = _External;

  const factory EmbedViewState.recordWithMedia({
    required EmbedViewRecordWithMedia data,
  }) = _RecordWithMedia;

  const factory EmbedViewState.video({
    required EmbedVideoView data,
  }) = _Video;
}

class EmbedViewNotifier
    extends AutoDisposeFamilyNotifier<EmbedViewState, EmbedView> {
  @override
  EmbedViewState build(EmbedView arg) {
    _processEmbedView(arg);
    return const EmbedViewState.initial();
  }

  Future<void> _processEmbedView(EmbedView embedView) async {
    state = const EmbedViewState.loading();

    try {
      await embedView.map(
        record: (record) async {
          state = EmbedViewState.record(data: record.data);
        },
        images: (images) async {
          state = EmbedViewState.images(data: images.data);
        },
        external: (external) async {
          state = EmbedViewState.external(data: external.data);
        },
        recordWithMedia: (recordWithMedia) async {
          state = EmbedViewState.recordWithMedia(data: recordWithMedia.data);
        },
        video: (video) async {
          state = EmbedViewState.video(data: video.data);
        },
        unknown: (unknown) async {
          state = const EmbedViewState.error('Unknown embed type');
        },
      );
    } catch (e) {
      state = EmbedViewState.error(e.toString());
    }
  }

  void refresh() {
    _processEmbedView(arg);
  }
}
