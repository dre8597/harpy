import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_text_entities.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/widgets/bluesky_text.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

enum MediaOverlayActions {
  retweet,
  favorite,
  spacer,
  download,
  show,
  actionsButton,
}

const kDefaultOverlayActions = {
  MediaOverlayActions.retweet,
  MediaOverlayActions.favorite,
  MediaOverlayActions.spacer,
  MediaOverlayActions.download,
  MediaOverlayActions.actionsButton,
};

class MediaGalleryOverlay extends ConsumerStatefulWidget {
  const MediaGalleryOverlay({
    required this.tweet,
    required this.delegates,
    required this.media,
    required this.child,
    this.actions = kDefaultOverlayActions,
  });

  final BlueskyPostData tweet;
  final BlueskyMediaData media;
  final TweetDelegates delegates;
  final Widget child;
  final Set<MediaOverlayActions> actions;

  @override
  ConsumerState<MediaGalleryOverlay> createState() => _MediaOverlayState();
}

class _MediaOverlayState extends ConsumerState<MediaGalleryOverlay>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _controller;
  late final Animation<Offset> _topAnimation;
  late final Animation<Offset> _bottomAnimation;

  RouteObserver? _observer;

  final _childKey = GlobalKey();
  final _appBarKey = GlobalKey();
  final _actionsKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _topAnimation = Tween(begin: const Offset(0, -1), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_controller);

    _bottomAnimation = Tween(begin: const Offset(0, 1), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_controller);

    _controller.forward();
  }

  @override
  void didPop() {
    _controller.reverse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _observer ??= ref.read(routeObserver)
      ?..subscribe(this, ModalRoute.of(context)!);

    _controller.duration = Theme.of(context).animation.short;
  }

  @override
  void dispose() {
    _observer?.unsubscribe(this);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tweet = ref.watch(tweetProvider(widget.tweet.id)) ?? widget.tweet;

    final overlap =
        tweet.media?.first.type.toMediaCategory != MediaType.video.name;

    final child = Center(
      key: _childKey,
      child: HarpyDismissible(
        onDismissed: Navigator.of(context).pop,
        child: widget.child,
      ),
    );

    final appBar = Align(
      key: _appBarKey,
      alignment: AlignmentDirectional.topCenter,
      child: SlideTransition(
        position: _topAnimation,
        child: const _OverlayAppBar(),
      ),
    );

    final actions = Align(
      key: _actionsKey,
      alignment: AlignmentDirectional.bottomCenter,
      child: SlideTransition(
        position: _bottomAnimation,
        child: _OverlayTweetActions(
          tweet: tweet,
          media: widget.media,
          delegates: widget.delegates,
          actions: widget.actions,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          if (!overlap) appBar,
          Expanded(
            child: Stack(
              children: [
                GestureDetector(onTap: Navigator.of(context).maybePop),
                child,
                if (overlap) appBar,
                if (overlap) actions,
              ],
            ),
          ),
          if (!overlap) actions,
        ],
      ),
    );
  }
}

class _OverlayAppBar extends ConsumerWidget {
  const _OverlayAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: IntrinsicHeight(
        child: GestureDetector(
          onTap: Navigator.of(context).maybePop,
          child: Container(
            alignment: AlignmentDirectional.centerStart,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topCenter,
                end: AlignmentDirectional.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            padding:
                EdgeInsets.symmetric(horizontal: theme.spacing.small).copyWith(
              top: theme.spacing.small + mediaQuery.padding.top,
            ),
            child: RbyButton.transparent(
              icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
              onTap: Navigator.of(context).maybePop,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayTweetActions extends ConsumerWidget {
  const _OverlayTweetActions({
    required this.tweet,
    required this.media,
    required this.delegates,
    required this.actions,
  });

  final BlueskyPostData tweet;
  final BlueskyMediaData media;
  final TweetDelegates delegates;
  final Set<MediaOverlayActions> actions;

  Widget _mapAction(
    WidgetRef ref, {
    required MediaOverlayActions action,
  }) {
    switch (action) {
      case MediaOverlayActions.retweet:
        return RetweetButton(
          tweet: tweet,
          sizeDelta: 2,
          foregroundColor: Colors.white,
          onRetweet: delegates.onRetweet,
          onUnretweet: delegates.onUnretweet,
          onShowRetweeters: delegates.onShowRetweeters,
          onComposeQuote: delegates.onComposeQuote,
        );
      case MediaOverlayActions.favorite:
        return FavoriteButton(
          tweet: tweet,
          sizeDelta: 2,
          foregroundColor: Colors.white,
          onFavorite: delegates.onFavorite,
          onUnfavorite: delegates.onUnfavorite,
          onShowLikes: delegates.onShowLikes,
        );
      case MediaOverlayActions.spacer:
        return const Spacer();
      case MediaOverlayActions.download:
        return DownloadButton(
          tweet: tweet,
          media: media,
          sizeDelta: 2,
          foregroundColor: Colors.white,
          onDownload: delegates.onDownloadMedia,
        );
      case MediaOverlayActions.show:
        return ShowButton(
          tweet: tweet,
          sizeDelta: 2,
          foregroundColor: Colors.white,
          onShow: delegates.onShowTweet,
        );
      case MediaOverlayActions.actionsButton:
        return MoreActionsButton(
          tweet: tweet,
          sizeDelta: 2,
          foregroundColor: Colors.white,
          onViewMoreActions: (ref) {
            showMediaActionsBottomSheet(
              ref,
              media: media,
              delegates: delegates,
            );
          },
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topCenter,
          end: AlignmentDirectional.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.small)
          .copyWith(bottom: mediaQuery.padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OverlayPreviewText(tweet: tweet, delegates: delegates),
          Row(
            children: [
              for (final action in actions) _mapAction(ref, action: action),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverlayPreviewText extends ConsumerWidget {
  const _OverlayPreviewText({
    required this.tweet,
    required this.delegates,
  });

  final BlueskyPostData tweet;
  final TweetDelegates delegates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final router = ref.watch(routerProvider);
    final launcher = ref.watch(launcherProvider);

    // Create entities from mentions and tags
    final entities = <BlueskyTextEntity>[];

    // Add mentions
    if (tweet.mentions != null) {
      for (final mention in tweet.mentions!) {
        // Find the @ symbol for this mention in the text
        final index = tweet.text.indexOf('@$mention');
        if (index != -1) {
          entities.add(
            BlueskyTextEntity(
              type: 'mention',
              value: mention,
              start: index,
              end: index + mention.length + 1, // +1 for @ symbol
            ),
          );
        }
      }
    }

    // Add tags
    if (tweet.tags != null) {
      for (final tag in tweet.tags!) {
        // Find the # symbol for this tag in the text
        final index = tweet.text.indexOf('#$tag');
        if (index != -1) {
          entities.add(
            BlueskyTextEntity(
              type: 'hashtag',
              value: tag,
              start: index,
              end: index + tag.length + 1, // +1 for # symbol
            ),
          );
        }
      }
    }

    // Add external URLs
    if (tweet.externalUrls != null) {
      for (final url in tweet.externalUrls!) {
        final index = tweet.text.indexOf(url);
        if (index != -1) {
          entities.add(
            BlueskyTextEntity(
              type: 'url',
              value: url,
              start: index,
              end: index + url.length,
            ),
          );
        }
      }
    }

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: theme.spacing.base,
        end: theme.spacing.base,
        top: theme.spacing.small,
        bottom: theme.spacing.small,
      ),
      child: AnimatedSize(
        duration: theme.animation.short,
        alignment: AlignmentDirectional.bottomCenter,
        curve: Curves.easeInOut,
        child: GestureDetector(
          onTap: () => delegates.onShowTweet?.call(ref),
          child: RbyAnimatedSwitcher(
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: AlignmentDirectional.bottomCenter,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            child: BlueskyText(
              tweet.text,
              key: ObjectKey(tweet),
              entities: entities,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: Colors.white,
              ),
              entityStyle: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              onMentionTap: (mention) {
                router.push('/user/$mention');
              },
              onHashtagTap: (hashtag) {
                router.push('/harpy_search/tweets?query=%23$hashtag');
              },
              onUrlTap: launcher,
            ),
          ),
        ),
      ),
    );
  }
}
