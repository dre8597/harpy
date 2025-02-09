import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harpy/api/bluesky/data/profile_data.dart';
import 'package:harpy/components/authentication/provider/profiles_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/login/bluesky_login_form.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/atproto.dart' show createSession;
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/data/models.dart' as models;
import 'package:harpy/components/settings/theme/provider/theme_provider.dart';

typedef AnimatedWidgetBuilder = Widget Function(
  AnimationController controller,
);

/// A fullscreen-sized navigation drawer for the [HomeTabView].
class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return _DrawerAnimationListener(
      builder: (controller) => SingleChildScrollView(
        padding: theme.spacing.edgeInsets,
        child: Column(
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

    void showProfileMenu(
      BuildContext context,
      WidgetRef ref,
      List<StoredProfileData> profiles,
    ) {
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Switch Account'),
              ),
              const Divider(),
              ...profiles.map(
                (profile) => ListTile(
                  leading: profile.avatar != null
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(profile.avatar!),
                        )
                      : const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                  title: Text(profile.displayName),
                  subtitle: Text('@${profile.handle}'),
                  trailing: profile.isActive
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () async {
                    if (!profile.isActive) {
                      await ref
                          .read(profilesProvider.notifier)
                          .switchToProfile(profile.did);
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.add),
                ),
                title: const Text('Add Account'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => const _AddAccountModal(),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: theme.shape.borderRadius,
      onTap: () => context.pushNamed(
        UserPage.name,
        pathParameters: {'authorDid': user.id},
      ),
      onLongPress: () => showProfileMenu(
        context,
        ref,
        ref.watch(profilesProvider).profiles,
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
                ),
              ),
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
                ),
              ),
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

class _ReAuthenticationModal extends ConsumerWidget {
  const _ReAuthenticationModal({
    required this.profile,
  });

  final StoredProfileData profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Re-authenticate ${profile.handle}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          BlueskyLoginForm(
            initialIdentifier: profile.handle,
            onLogin: (identifier, password) async {
              try {
                // Create session
                final service = ref.read(blueskyServiceProvider);
                final session = await createSession(
                  service: service,
                  identifier: identifier,
                  password: password,
                );

                // Update profile with new credentials
                final updatedProfile = profile.copyWith(
                  appPassword: password,
                  accessJwt: session.data.accessJwt,
                  refreshJwt: session.data.refreshJwt,
                  isActive: true,
                );

                // Update profile and switch to it
                await ref
                    .read(profilesProvider.notifier)
                    .addProfile(updatedProfile);
                await ref
                    .read(profilesProvider.notifier)
                    .switchToProfile(profile.did);

                ref
                    .read(messageServiceProvider)
                    .showText('Successfully re-authenticated');

                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (error) {
                ref
                    .read(messageServiceProvider)
                    .showText('Failed to re-authenticate');
              }
            },
          ),
        ],
      ),
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

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final profilesNotifier = ref.read(profilesProvider.notifier);
    final currentProfile = profilesNotifier.getActiveProfile();

    if (currentProfile == null) {
      // No active profile, just go to login
      ref.read(routerProvider).goNamed(LoginPage.name);
      return;
    }

    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context),
        child: const LogoutDialog(),
      ),
    );

    if (shouldLogout != true) return;

    // Get all profiles except current one
    final remainingProfiles = ref
        .read(profilesProvider)
        .profiles
        .where((p) => p.did != currentProfile.did)
        .toList();

    // Remove current profile
    await profilesNotifier.removeProfile(currentProfile.did);

    if (remainingProfiles.isEmpty) {
      // No other profiles, go to login page
      ref.read(authenticationStateProvider.notifier).state =
          const AuthenticationState.unauthenticated();
      ref.read(routerProvider).goNamed(LoginPage.name);
      return;
    }

    // Try to switch to next profile
    final nextProfile = remainingProfiles.first;
    try {
      // Try to validate the session
      final service = ref.read(blueskyServiceProvider);
      final session = await createSession(
        service: service,
        identifier: nextProfile.handle,
        password: nextProfile.appPassword,
      );

      // Session is valid, update profile and switch
      final updatedProfile = nextProfile.copyWith(
        accessJwt: session.data.accessJwt,
        refreshJwt: session.data.refreshJwt,
      );
      await profilesNotifier.addProfile(updatedProfile);
      await profilesNotifier.switchToProfile(nextProfile.did);

      ref
          .read(messageServiceProvider)
          .showText('Switched to ${nextProfile.handle}');
    } catch (e) {
      // Session is invalid, show re-authentication modal
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => _ReAuthenticationModal(profile: nextProfile),
        );
      }
    }
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
        onTap: () => _handleLogout(context, ref),
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

class _AddAccountModal extends ConsumerWidget {
  const _AddAccountModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Add Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          BlueskyLoginForm(
            onLogin: (identifier, password) async {
              try {
                // Create session
                final service = ref.read(blueskyServiceProvider);
                final session = await createSession(
                  service: service,
                  identifier: identifier,
                  password: password,
                );

                // Get authenticated instance
                final bluesky = bsky.Bluesky.fromSession(
                  session.data,
                  service: service,
                );

                // Get user profile
                final profile =
                    await bluesky.actor.getProfile(actor: identifier);

                // Create profile data
                final profileData = StoredProfileData.fromProfile(
                  profile: models.Profile(
                    did: profile.data.did,
                    handle: profile.data.handle,
                    displayName: profile.data.displayName,
                    description: profile.data.description,
                    avatar: profile.data.avatar,
                    banner: profile.data.banner,
                    followersCount: profile.data.followersCount,
                    followsCount: profile.data.followsCount,
                    postsCount: profile.data.postsCount,
                    viewer: models.ProfileViewer(
                      following: profile.data.viewer.following?.toString(),
                      followedBy: profile.data.viewer.followedBy?.toString(),
                      blocking: profile.data.viewer.blocking?.toString(),
                    ),
                  ),
                  appPassword: password,
                  accessJwt: session.data.accessJwt,
                  refreshJwt: session.data.refreshJwt,
                  isActive: true,
                  mediaPreferences: ref.read(mediaPreferencesProvider),
                  feedPreferences: ref.read(feedPreferencesProvider),
                  themeMode: ref.read(themeProvider).themeMode.name,
                );

                // Check if profile already exists
                final existingProfiles = ref.read(profilesProvider).profiles;
                final existingProfile = existingProfiles.firstWhere(
                  (p) => p.did == profile.data.did,
                  orElse: () => profileData,
                );

                if (existingProfile != profileData) {
                  // Profile exists, update it
                  final updatedProfile = existingProfile.copyWith(
                    appPassword: password,
                    accessJwt: session.data.accessJwt,
                    refreshJwt: session.data.refreshJwt,
                    isActive: true,
                  );
                  await ref
                      .read(profilesProvider.notifier)
                      .addProfile(updatedProfile);
                  await ref
                      .read(profilesProvider.notifier)
                      .switchToProfile(profile.data.did);
                  ref
                      .read(messageServiceProvider)
                      .showText('Successfully updated account');
                } else {
                  // Add new profile
                  await ref
                      .read(profilesProvider.notifier)
                      .addProfile(profileData);
                  await ref
                      .read(profilesProvider.notifier)
                      .switchToProfile(profile.data.did);
                  ref
                      .read(messageServiceProvider)
                      .showText('Successfully added account');
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (error) {
                ref
                    .read(messageServiceProvider)
                    .showText('Failed to add account: $error');
              }
            },
          ),
        ],
      ),
    );
  }
}
