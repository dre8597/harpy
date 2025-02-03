import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

typedef AnimatedWidgetBuilder = Widget Function(
  AnimationController controller,
);

/// A fullscreen-sized navigation drawer for the [HomeTabView].
class HomeDrawer extends StatelessWidget {
  const HomeDrawer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _DrawerAnimationListener(
      builder: (controller) => ListView(
        padding: theme.spacing.edgeInsets,
        children: [
          const HomeTopPadding(),
          const _AuthenticatedUser(),
          VerticalSpacer.normal,
          const _ConnectionsCount(),
          VerticalSpacer.normal,
          VerticalSpacer.normal,
          _Entries(controller),
          const HomeBottomPadding(),
        ],
      ),
    );
  }
}

/// Listens to the animation of the [DefaultTabController] and exposes its value
/// in the [builder].
class _DrawerAnimationListener extends StatefulWidget {
  const _DrawerAnimationListener({
    required this.builder,
  });

  final AnimatedWidgetBuilder builder;

  @override
  _DrawerAnimationListenerState createState() =>
      _DrawerAnimationListenerState();
}

class _DrawerAnimationListenerState extends State<_DrawerAnimationListener>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  TabController? _tabController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _tabController = HomeTabController.of(context)!
      ..animation!.addListener(_tabControllerListener);
  }

  @override
  void dispose() {
    _tabController?.animation?.removeListener(_tabControllerListener);
    _controller.dispose();

    super.dispose();
  }

  void _tabControllerListener() {
    if (mounted) {
      final value = 1 - _tabController!.animation!.value;

      if (value >= 0 && value <= 1 && value != _controller.value) {
        _controller.value = value;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_controller);
  }
}

class _AuthenticatedUser extends ConsumerWidget {
  const _AuthenticatedUser();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authenticationStateProvider).user;

    if (user == null) {
      return const SizedBox();
    }

    return InkWell(
      borderRadius: theme.shape.borderRadius,
      onTap: () => context.pushNamed(
        UserPage.name,
        pathParameters: {'authorDid': user.id},
      ),
      child: Card(
        child: Padding(
          padding: theme.spacing.edgeInsets,
          child: Row(
            children: [
              if (user.profileImage?.bigger != null) ...[
                HarpyCircleAvatar(
                  radius: 28,
                  imageUrl: user.profileImage!.bigger!.toString(),
                ),
                HorizontalSpacer.normal,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.headlineSmall,
                    ),
                    VerticalSpacer.small,
                    Text(
                      '@${user.handle}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionsCount extends ConsumerWidget {
  const _ConnectionsCount();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authenticationStateProvider).user;

    if (user == null) {
      return const SizedBox();
    }

    final theme = Theme.of(context);
    final textStyle = TextStyle(color: theme.colorScheme.onSurface);

    return Row(
      children: [
        Expanded(
          child: ConnectionCount(
            count: user.followingCount,
            builder: (count) => RbyListCard(
              title: FittedBox(
                  child: Text(
                '$count  following',
                style: textStyle,
              )),
              onTap: () => context.pushNamed(
                FollowingPage.name,
                pathParameters: {'authorDid': user.id},
              ),
            ),
          ),
        ),
        HorizontalSpacer.normal,
        Expanded(
          child: ConnectionCount(
            count: user.followersCount,
            builder: (count) => RbyListCard(
              title: FittedBox(
                  child: Text(
                '$count  followers',
                style: textStyle,
              )),
              onTap: () => context.pushNamed(
                FollowersPage.name,
                pathParameters: {'authorDid': user.id},
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Entries extends ConsumerWidget {
  const _Entries(this.controller);

  final AnimationController controller;

  List<Widget> _animate(
    List<Widget> children, {
    required TextDirection directionality,
  }) {
    final animated = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      final offsetAnimation = Tween<Offset>(
        begin: Offset(
          lerpDouble(
            directionality == TextDirection.ltr ? -.3 : .3,
            directionality == TextDirection.ltr ? -2 : 2,
            i / children.length,
          )!,
          0,
        ),
        end: Offset.zero,
      ).animate(controller);

      animated.add(
        FractionalTranslation(
          translation: offsetAnimation.value,
          child: Opacity(
            opacity: controller.value,
            child: children[i],
          ),
        ),
      );
    }

    return animated;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final general = ref.watch(generalPreferencesProvider);
    final user = ref.watch(authenticationStateProvider).user;
    final launcher = ref.watch(launcherProvider);

    final directionality = Directionality.of(context);

    if (user == null) return const SizedBox();
    final textStyle = TextStyle(color: theme.colorScheme.onSurface);

    final children = [
      RbyListCard(
        leading: const Icon(CupertinoIcons.person),
        title: Text('profile', style: textStyle),
        onTap: () => context.pushNamed(
          UserPage.name,
          pathParameters: {'authorDid': user.handle},
        ),
      ),
      VerticalSpacer.normal,
      RbyListCard(
        leading: const Icon(CupertinoIcons.search),
        title: Text('search', style: textStyle),
        onTap: () => context.pushNamed(SearchPage.name),
      ),
      VerticalSpacer.normal,
      RbyListCard(
        leading: const Icon(CupertinoIcons.list_bullet),
        title: Text('lists', style: textStyle),
        onTap: () => context.pushNamed(
          ListShowPage.name,
          pathParameters: {'authorDid': user.id},
        ),
      ),
      VerticalSpacer.normal,
      RbyListCard(
        leading: const Icon(FeatherIcons.feather),
        title: Text('compose', style: textStyle),
        onTap: () => context.pushNamed(ComposePage.name),
      ),
      VerticalSpacer.normal,
      VerticalSpacer.normal,
      RbyListCard(
        leading: const Icon(Icons.settings_rounded),
        title: Text(
          'settings',
          style: textStyle,
        ),
        onTap: () => context.pushNamed(SettingsPage.name),
      ),
      VerticalSpacer.normal,
      if (isFree) ...[
        RbyListCard(
          leading: const FlareIcon.shiningStar(),
          title: Text('harpy pro', style: textStyle),
          onTap: () => launcher(
            'https://play.google.com/store/apps/details?id=com.robertodoering.harpy.pro',
          ),
        ),
        VerticalSpacer.normal,
      ],
      RbyListCard(
        leading: const FlareIcon.harpyLogo(),
        title: Text('about', style: textStyle),
        onTap: () => context.pushNamed(AboutPage.name),
      ),
      VerticalSpacer.normal,
      VerticalSpacer.normal,
      RbyListCard(
        leading: Icon(
          CupertinoIcons.square_arrow_left,
          color: theme.colorScheme.error,
        ),
        title: Text('logout', style: textStyle),
        onTap: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => Theme(
              data: Theme.of(context),
              child: const LogoutDialog(),
            ),
          );

          if (result ?? false) ref.read(logoutProvider).logout().ignore();
        },
      ),
    ];

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Column(
        children: general.performanceMode
            ? children
            : _animate(
                children,
                directionality: directionality,
              ),
      ),
    );
  }
}
