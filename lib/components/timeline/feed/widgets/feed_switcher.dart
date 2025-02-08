import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/authentication/provider/profiles_provider.dart';
import 'package:rby/rby.dart';

class FeedSwitcher extends ConsumerWidget {
  const FeedSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeTimelineProvider);
    final feedPreferences = ref.watch(feedPreferencesProvider);

    return RbyButton.card(
      icon: const Icon(Icons.feed),
      onTap: state is! TimelineStateLoading
          ? () async {
              final uri = await showFeedSwitcherDialog(context, feedPreferences);
              if (uri != null && context.mounted) {
                // Set the active feed
                await ref.read(feedPreferencesProvider.notifier).setActiveFeed(uri);

                // Store the feed preference in the current profile
                final currentProfile = ref.read(profilesProvider.notifier).getActiveProfile();
                if (currentProfile != null) {
                  final updatedProfile = currentProfile.copyWith(
                    feedPreferences: feedPreferences.copyWith(activeFeedUri: uri),
                  );
                  await ref.read(profilesProvider.notifier).addProfile(updatedProfile);
                }

                // Reload the timeline with the new feed
                if (context.mounted) {
                  await ref.read(homeTimelineProvider.notifier).load(clearPrevious: true);
                }
              }
            }
          : null,
    );
  }
}

Future<String?> showFeedSwitcherDialog(
  BuildContext context,
  FeedPreferences feedPreferences,
) {
  final theme = Theme.of(context);
  final size = MediaQuery.of(context).size;

  return showDialog<String>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.85,
          maxHeight: size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Switch Feed',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final feed in feedPreferences.feeds)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.feed, size: 20),
                          title: Text(
                            feed.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: feed.uri == feedPreferences.activeFeedUri
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                          subtitle: feed.description != null
                              ? Text(
                                  feed.description!,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: feed.uri == feedPreferences.activeFeedUri
                              ? Icon(
                                  Icons.check,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(feed.uri),
                        ),
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.add, size: 20),
                        title: const Text('Add Custom Feed'),
                        onTap: () {
                          // TODO: Implement custom feed addition
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
