import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';

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
    required this.provider,
    required this.delegates,
    required this.media,
    required this.child,
    this.actions = kDefaultOverlayActions,
  });

  final StateNotifierProvider<TweetNotifier, TweetData> provider;
  final MediaData media;
  final TweetDelegates delegates;
  final Widget child;
  final Set<MediaOverlayActions> actions;

  @override
  _MediaOverlayState createState() => _MediaOverlayState();
}

class _MediaOverlayState extends ConsumerState<MediaGalleryOverlay>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _controller;
  late final Animation<Offset> _topAnimation;
  late final Animation<Offset> _bottomAnimation;

  RouteObserver? _observer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: kShortAnimationDuration,
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
  }

  @override
  void dispose() {
    _observer?.unsubscribe(this);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tweet = ref.watch(widget.provider);

    return Stack(
      children: [
        GestureDetector(onTap: Navigator.of(context).pop),
        AnimatedBuilder(
          animation: _controller,
          builder: (_, child) => Column(
            children: [
              SlideTransition(
                position: _topAnimation,
                child: const _OverlayAppBar(),
              ),
              child!,
              SlideTransition(
                position: _bottomAnimation,
                child: _OverlayTweetActions(
                  tweet: tweet,
                  media: widget.media,
                  delegates: widget.delegates,
                  actions: widget.actions,
                ),
              ),
            ],
          ),
          child: Expanded(
            child: Center(
              child: HarpyDismissible(
                onDismissed: Navigator.of(context).pop,
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayAppBar extends ConsumerWidget {
  const _OverlayAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final display = ref.watch(displayPreferencesProvider);

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Container(
        alignment: Alignment.centerLeft,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black87,
              Colors.transparent,
            ],
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: display.smallPaddingValue)
            .copyWith(top: display.smallPaddingValue + mediaQuery.padding.top),
        child: HarpyButton.icon(
          icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
          onTap: Navigator.of(context).maybePop,
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

  final TweetData tweet;
  final MediaData media;
  final TweetDelegates delegates;
  final Set<MediaOverlayActions> actions;

  Widget _mapAction({
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
        );
      case MediaOverlayActions.spacer:
        return const Spacer();
      case MediaOverlayActions.download:
        return DownloadButton(
          tweet: tweet,
          sizeDelta: 2,
          foregroundColor: Colors.white,
          // TODO: download
          onDownload: (_, __) {},
        );
      case MediaOverlayActions.show:
        return ShowButton(
          tweet: tweet,
          sizeDelta: 2,
          foregroundColor: Colors.white,
          onShow: delegates.onTweetTap,
        );
      case MediaOverlayActions.actionsButton:
        return MoreActionsButton(
          tweet: tweet,
          sizeDelta: 2,
          foregroundColor: Colors.white,
          onViewMoreActions: (context, read) => showMediaActionsBottomSheet(
            context,
            read: read,
            tweet: tweet,
            media: media,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final display = ref.watch(displayPreferencesProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black87,
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: display.smallPaddingValue)
          .copyWith(bottom: mediaQuery.padding.bottom),
      child: Row(
        children: [
          for (final action in actions) _mapAction(action: action),
        ],
      ),
    );
  }
}
