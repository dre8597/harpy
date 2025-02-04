import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/data/list_data.dart';
import 'package:harpy/api/twitter/data/user_data.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/likes/likes_page.dart';
import 'package:harpy/core/core.dart';

final routeObserver = Provider(
  name: 'RouteObserver',
  (ref) => RouteObserver(),
);

final routerProvider = Provider(
  name: 'RouterProvider',
  (ref) => GoRouter(
    routes: ref.watch(routesProvider),
    redirect: (context, state) => handleRedirect(ref, state),
    errorBuilder: (context, state) => ErrorPage(error: state.error),
    observers: [
      ref.watch(routeObserver),
      ref.watch(videoAutopauseObserver),
    ],
  ),
);

CustomTransitionPage<void> _buildTransitionPage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  bool fullscreenDialog = false,
}) {
  final transitionType = state.uri.queryParameters['transition'] == 'fade'
      ? TransitionType.fade
      : TransitionType.native;

  return CustomTransitionPage(
    key: ValueKey(state.uri.toString()),
    child: child,
    fullscreenDialog: fullscreenDialog,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (transitionType) {
        case TransitionType.fade:
          return FadeTransition(opacity: animation, child: child);
        case TransitionType.native:
          return child;
      }
    },
  );
}

enum TransitionType {
  fade,
  native,
}

final routesProvider = Provider(
  name: 'RoutesProvider',
  (ref) => [
    GoRoute(
      name: SplashPage.name,
      path: SplashPage.path,
      pageBuilder: (context, state) => _buildTransitionPage(
        context: context,
        state: state,
        child: SplashPage(
          redirect: state.uri.queryParameters['redirect'],
        ),
      ),
    ),
    GoRoute(
      name: LoginPage.name,
      path: LoginPage.path,
      pageBuilder: (context, state) => _buildTransitionPage(
        context: context,
        state: state,
        child: const LoginPage(),
      ),
      routes: [
        GoRoute(
          name: CustomApiPage.name,
          path: CustomApiPage.path,
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            fullscreenDialog: true,
            child: const CustomApiPage(),
          ),
        ),
      ],
    ),
    GoRoute(
      name: WebviewPage.name,
      path: '/webview',
      builder: (context, state) => WebviewPage(
        initialUrl: state.uri.queryParameters['initialUrl']!,
      ),
    ),
    GoRoute(
      name: AboutPage.name,
      path: AboutPage.path, // '/about_harpy'
      builder: (context, state) => const AboutPage(),
      routes: [
        GoRoute(
          name: ChangelogPage.name,
          path: 'changelog',
          builder: (context, state) => const ChangelogPage(),
        ),
      ],
    ),
    GoRoute(
      name: SetupPage.name,
      path: '/setup',
      builder: (context, state) => const SetupPage(),
    ),
    GoRoute(
      name: HomePage.name,
      path: '/',
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          name: UserPage.name,
          path: 'user/:authorDid',
          builder: (context, state) =>
              UserPage(authorDid: state.pathParameters['authorDid']!),
          routes: [
            GoRoute(
              name: FollowingPage.name,
              path: 'following',
              builder: (context, state) =>
                  FollowingPage(handle: state.pathParameters['authorDid']!),
            ),
            GoRoute(
              name: FollowersPage.name,
              path: 'followers',
              builder: (context, state) =>
                  FollowersPage(userId: state.pathParameters['authorDid']!),
            ),
            GoRoute(
              name: ListShowPage.name,
              path: 'lists',
              builder: (context, state) => ListShowPage(
                handle: state.pathParameters['authorDid']!,
                onListSelected: state.extra as ValueChanged<BlueskyListData>?,
              ),
            ),
            GoRoute(
              name: UserTimelineFilter.name,
              path: 'filter',
              builder: (context, state) =>
                  UserTimelineFilter(user: state.extra! as UserData),
            ),
            GoRoute(
              name: TweetDetailPage.name,
              path: 'status/:id',
              builder: (context, state) => TweetDetailPage(
                id: state.pathParameters['id']!,
                tweet: state.extra as BlueskyPostData?,
              ),
              routes: [
                GoRoute(
                  name: RetweetersPage.name,
                  path: 'retweets',
                  builder: (context, state) =>
                      RetweetersPage(tweetId: state.pathParameters['id']!),
                ),
                GoRoute(
                  name: LikesPage.name,
                  path: 'likes',
                  builder: (context, state) =>
                      LikesPage(tweetId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          name: HomeTimelineFilter.name,
          path: 'filter',
          builder: (context, state) => const HomeTimelineFilter(),
          routes: [
            GoRoute(
              name: TimelineFilterCreation.name,
              path: 'create',
              builder: (context, state) => TimelineFilterCreation(
                initialTimelineFilter: (state.extra
                    as Map?)?['initialTimelineFilter'] as TimelineFilter?,
                onSaved: (state.extra as Map?)?['onSaved']
                    as ValueChanged<TimelineFilter>?,
              ),
            ),
          ],
        ),
        GoRoute(
          name: SearchPage.name,
          path: 'harpy_search',
          builder: (context, state) => const SearchPage(),
          routes: [
            GoRoute(
              name: UserSearchPage.name,
              path: 'users',
              builder: (context, state) => const UserSearchPage(),
            ),
            GoRoute(
              name: TweetSearchPage.name,
              path: 'tweets',
              builder: (context, state) => TweetSearchPage(
                initialQuery: state.uri.queryParameters['query'],
              ),
              routes: [
                GoRoute(
                  name: TweetSearchFilter.name,
                  path: 'filter',
                  builder: (context, state) => TweetSearchFilter(
                    initialFilter: (state.extra as Map?)?['initialFilter']
                        as TweetSearchFilterData?,
                    onSaved: (state.extra as Map?)?['onSaved']
                        as ValueChanged<TweetSearchFilterData>?,
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          name: ListTimelinePage.name,
          path: 'i/lists/:listId',
          builder: (context, state) => ListTimelinePage(
            listId: state.pathParameters['listId']!,
            listName: state.uri.queryParameters['name']!,
          ),
          routes: [
            GoRoute(
              name: ListMembersPage.name,
              path: 'members',
              builder: (context, state) => ListMembersPage(
                listId: state.pathParameters['listId']!,
                listName: state.uri.queryParameters['name']!,
              ),
            ),
            GoRoute(
              name: ListTimelineFilter.name,
              path: 'filter',
              builder: (context, state) => ListTimelineFilter(
                listId: state.pathParameters['listId']!,
                listName: state.uri.queryParameters['name']!,
              ),
            ),
          ],
        ),
        GoRoute(
          name: ComposePage.name,
          path: 'compose/tweet',
          builder: (context, state) => ComposePage(
            parentTweet:
                (state.extra as Map?)?['parentTweet'] as BlueskyPostData?,
            quotedTweet:
                (state.extra as Map?)?['quotedTweet'] as BlueskyPostData?,
          ),
        ),
        GoRoute(
          name: SettingsPage.name,
          path: 'settings',
          builder: (context, state) => const SettingsPage(),
          routes: [
            GoRoute(
              name: MediaSettingsPage.name,
              path: 'media',
              builder: (context, state) => const MediaSettingsPage(),
            ),
            GoRoute(
              name: ThemeSettingsPage.name,
              path: 'theme',
              builder: (context, state) => const ThemeSettingsPage(),
              routes: [
                GoRoute(
                  name: CustomThemePage.name,
                  path: 'custom',
                  builder: (context, state) => CustomThemePage(
                    themeId: int.tryParse(
                      state.uri.queryParameters['themeId'] ?? '',
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              name: DisplaySettingsPage.name,
              path: 'display',
              builder: (context, state) => const DisplaySettingsPage(),
              routes: [
                GoRoute(
                  name: FontSelectionPage.name,
                  path: 'font',
                  builder: (context, state) => FontSelectionPage(
                    title: (state.extra as Map?)?['title'] as String,
                    selectedFont:
                        (state.extra as Map?)?['selectedFont'] as String,
                    onChanged: (state.extra as Map?)?['onChanged']
                        as ValueChanged<String>,
                  ),
                ),
              ],
            ),
            GoRoute(
              name: GeneralSettingsPage.name,
              path: 'general',
              builder: (context, state) => const GeneralSettingsPage(),
            ),
            GoRoute(
              name: LanguageSettingsPage.name,
              path: 'language',
              builder: (context, state) => const LanguageSettingsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
