import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/likes/provider/likes_provider.dart';

class LikesPage extends ConsumerWidget {
  const LikesPage({
    required this.tweetId,
  });

  final String tweetId;

  static const name = 'likes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(likesProvider(tweetId));

    return HarpyScaffold(
      child: ScrollDirectionListener(
        child: ScrollToTop(
          child: LegacyUserList(
            state.whenOrNull(data: (users) => users.toList()) ?? [],
            beginSlivers: const [
              HarpySliverAppBar(title: Text('liked by')),
            ],
            endSlivers: [
              ...?state.whenOrNull(
                loading: () => [const UserListLoadingSliver()],
                data: (users) => [
                  if (users.isEmpty)
                    const SliverFillInfoMessage(
                      secondaryMessage: Text('no likes'),
                    ),
                ],
                error: (_, __) => const [
                  SliverFillLoadingError(
                    message: Text('error loading likes'),
                  ),
                ],
              ),
              const SliverBottomPadding(),
            ],
          ),
        ),
      ),
    );
  }
}
