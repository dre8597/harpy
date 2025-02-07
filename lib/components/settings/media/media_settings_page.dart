import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

class MediaSettingsPage extends ConsumerWidget {
  const MediaSettingsPage();

  static const name = 'media_settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return HarpyScaffold(
      child: CustomScrollView(
        slivers: [
          HarpySliverAppBar(
            title: const Text('media'),
            actions: [
              RbyPopupMenuButton(
                onSelected: (_) {
                  ref.read(mediaPreferencesProvider.notifier).defaultSettings();
                  ref.read(downloadPathProvider.notifier).initialize();
                },
                itemBuilder: (_) => const [
                  RbyPopupMenuListTile(
                    value: true,
                    title: Text('reset to default'),
                  ),
                ],
              ),
            ],
          ),
          SliverPadding(
            padding: theme.spacing.edgeInsets,
            sliver: const _MediaSettingsList(),
          ),
          const SliverBottomPadding(),
        ],
      ),
    );
  }
}

class _MediaSettingsList extends ConsumerWidget {
  const _MediaSettingsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onBackground = theme.colorScheme.onSurface;

    final media = ref.watch(mediaPreferencesProvider);
    final mediaNotifier = ref.watch(mediaPreferencesProvider.notifier);

    return SliverList(
      delegate: SliverChildListDelegate.fixed([
        Card(
          child: HarpyRadioDialogTile(
            leading: const Icon(CupertinoIcons.photo),
            title: const Text('tweet image quality'),
            borderRadius: theme.shape.borderRadius,
            dialogTitle: Text(
              'change when tweet images use the best quality',
              style: TextStyle(color: onBackground),
            ),
            entries: {
              0: Text(
                'always use best quality',
                style: TextStyle(color: onBackground),
              ),
              1: Text(
                'only use best quality on wifi',
                style: TextStyle(color: onBackground),
              ),
              2: Text(
                'never use best quality',
                style: TextStyle(color: onBackground),
              ),
            },
            groupValue: media.bestMediaQuality,
            onChanged: mediaNotifier.setBestMediaQuality,
          ),
        ),
        VerticalSpacer.normal,
        const _MediaInfoMessage(),
        VerticalSpacer.normal,
        Card(
          child: RbySwitchTile(
            leading: const Icon(CupertinoIcons.crop),
            title: Text(
              'crop tweet image',
              style: TextStyle(color: onBackground),
            ),
            subtitle: const Text('reduces height'),
            value: media.cropImage,
            borderRadius: theme.shape.borderRadius,
            onChanged: mediaNotifier.setCropImage,
          ),
        ),
        VerticalSpacer.normal,
        Card(
          child: RbySwitchTile(
            leading: const Icon(CupertinoIcons.eye_slash_fill),
            title: Text(
              'hide possibly sensitive media',
              style: TextStyle(color: onBackground),
            ),
            value: media.hidePossiblySensitive,
            borderRadius: theme.shape.borderRadius,
            onChanged: mediaNotifier.setHidePossiblySensitive,
          ),
        ),
        VerticalSpacer.normal,
        Card(
          child: RbySwitchTile(
            leading: const Icon(CupertinoIcons.link),
            title: Text(
              'open links externally',
              style: TextStyle(color: onBackground),
            ),
            value: media.openLinksExternally,
            borderRadius: theme.shape.borderRadius,
            onChanged: mediaNotifier.setOpenLinksExternally,
          ),
        ),
        VerticalSpacer.normal,
        ExpansionCard(
          title: Text(
            'autoplay',
            style: TextStyle(color: onBackground),
          ),
          children: [
            HarpyRadioDialogTile(
              leading: const Icon(CupertinoIcons.play_circle),
              title: Text(
                'autoplay gifs',
                style: TextStyle(color: onBackground),
              ),
              dialogTitle: Text(
                'change when gifs should automatically play',
                style: TextStyle(color: onBackground),
              ),
              entries: {
                0: Text(
                  'always autoplay',
                  style: TextStyle(color: onBackground),
                ),
                1: Text('only on wifi', style: TextStyle(color: onBackground)),
                2: Text(
                  'never autoplay',
                  style: TextStyle(color: onBackground),
                ),
              },
              groupValue: media.autoplayGifs,
              onChanged: mediaNotifier.setAutoplayGifs,
            ),
            HarpyRadioDialogTile(
              leading: Icon(CupertinoIcons.play_circle, color: onBackground),
              title: Text(
                'autoplay videos',
                style: TextStyle(color: onBackground),
              ),
              dialogTitle: Text(
                'change when videos should automatically play',
                style: TextStyle(color: onBackground),
              ),
              entries: {
                0: Text(
                  'always autoplay',
                  style: TextStyle(color: onBackground),
                ),
                1: Text('only on wifi', style: TextStyle(color: onBackground)),
                2: Text(
                  'never autoplay',
                  style: TextStyle(color: onBackground),
                ),
              },
              groupValue: media.autoplayVideos,
              onChanged: mediaNotifier.setAutoplayVideos,
            ),
            HarpyRadioDialogTile(
              leading: const Icon(CupertinoIcons.arrow_down_circle),
              title: Text(
                'preload videos',
                style: TextStyle(color: onBackground),
              ),
              dialogTitle: Text(
                'change when videos should be preloaded',
                style: TextStyle(color: onBackground),
              ),
              entries: {
                0: Text(
                  'always preload',
                  style: TextStyle(color: onBackground),
                ),
                1: Text('only on wifi', style: TextStyle(color: onBackground)),
                2: Text('never preload', style: TextStyle(color: onBackground)),
              },
              groupValue: media.preloadVideos,
              onChanged: mediaNotifier.setPreloadVideos,
            ),
          ],
        ),
        VerticalSpacer.normal,
        Card(
          child: RbySwitchTile(
            leading: const Icon(CupertinoIcons.volume_off),
            title: Text(
              'start video playback muted',
              style: TextStyle(color: onBackground),
            ),
            value: media.startVideoPlaybackMuted,
            borderRadius: theme.shape.borderRadius,
            onChanged: mediaNotifier.setStartVideoPlaybackMuted,
          ),
        ),
        VerticalSpacer.normal,
        Card(
          child: RbySwitchTile(
            leading: const Icon(CupertinoIcons.play_rectangle_fill),
            title: Text(
              'reels video mode',
              style: TextStyle(color: onBackground),
            ),
            subtitle: const Text('TikTok/Instagram Reels style video feed'),
            value: media.useReelsVideoMode,
            borderRadius: theme.shape.borderRadius,
            onChanged: mediaNotifier.setUseReelsVideoMode,
          ),
        ),
        VerticalSpacer.normal,
        const _MediaDownloadSettings(),
      ]),
    );
  }
}

class _MediaDownloadSettings extends ConsumerStatefulWidget {
  const _MediaDownloadSettings();

  @override
  _MediaDownloadSettingsState createState() => _MediaDownloadSettingsState();
}

class _MediaDownloadSettingsState
    extends ConsumerState<_MediaDownloadSettings> {
  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      ref.read(downloadPathProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = ref.watch(mediaPreferencesProvider);
    final mediaNotifier = ref.watch(mediaPreferencesProvider.notifier);
    final downloadPath = ref.watch(downloadPathProvider);
    final onBackground = theme.colorScheme.onSurface;

    return ExpansionCard(
      title: const Text('download'),
      children: [
        RbySwitchTile(
          leading: const Icon(CupertinoIcons.arrow_down_to_line),
          title: Text(
            'show download dialog',
            style: TextStyle(color: onBackground),
          ),
          value: media.showDownloadDialog,
          onChanged: mediaNotifier.setShowDownloadDialog,
        ),
        RbyListTile(
          leading: const Icon(CupertinoIcons.folder),
          title: Text(
            'image download location',
            style: TextStyle(color: onBackground),
          ),
          subtitle: Text(downloadPath.imageFullPath ?? ''),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => const DownloadPathSelectionDialog(
              type: 'image',
            ),
          ),
        ),
        RbyListTile(
          leading: const Icon(CupertinoIcons.folder),
          title: Text(
            'gif download location',
            style: TextStyle(color: onBackground),
          ),
          subtitle: Text(downloadPath.gifFullPath ?? ''),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => const DownloadPathSelectionDialog(type: 'gif'),
          ),
        ),
        RbyListTile(
          leading: const Icon(CupertinoIcons.folder),
          title: Text(
            'video download location',
            style: TextStyle(color: onBackground),
          ),
          subtitle: Text(downloadPath.videoFullPath ?? ''),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => const DownloadPathSelectionDialog(
              type: 'video',
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaInfoMessage extends StatelessWidget {
  const _MediaInfoMessage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // align with the text in the list tile
        HorizontalSpacer.normal,
        Icon(
          CupertinoIcons.info,
          color: theme.colorScheme.primary,
        ),
        SizedBox(width: theme.spacing.base * 2),
        Expanded(
          child: Text(
            'media is always downloaded in the best quality',
            style: theme.textTheme.titleSmall!.apply(
              fontSizeDelta: -2,
              color: theme.colorScheme.onSurface.withAlpha(179),
            ),
          ),
        ),
        HorizontalSpacer.normal,
      ],
    );
  }
}
