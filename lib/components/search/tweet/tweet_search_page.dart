import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

class TweetSearchPage extends ConsumerStatefulWidget {
  const TweetSearchPage({
    this.initialQuery,
    this.hashTag,
    this.author,
    this.url,
    super.key,
  });

  final String? initialQuery;
  final String? hashTag;
  final String? author;
  final String? url;

  static const name = 'tweet_search';

  @override
  ConsumerState<TweetSearchPage> createState() => _TweetSearchPageState();
}

class _TweetSearchPageState extends ConsumerState<TweetSearchPage> {
  @override
  void initState() {
    super.initState();

    if (widget.initialQuery != null ||
        widget.hashTag != null ||
        widget.author != null ||
        widget.url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(tweetSearchProvider.notifier).search(
              customQuery: widget.initialQuery,
              hashTag: widget.hashTag,
              filter: widget.author != null || widget.url != null
                  ? TweetSearchFilterData(
                      author: widget.author ?? '',
                      url: widget.url ?? '',
                    )
                  : null,
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tweetSearchProvider);
    final notifier = ref.watch(tweetSearchProvider.notifier);

    return HarpyScaffold(
      child: ScrollDirectionListener(
        child: ScrollToTop(
          child: Builder(
            builder: (context) => RefreshIndicator(
              onRefresh: () async {
                UserScrollDirection.of(context)?.idle();
                await notifier.refresh();
              },
              edgeOffset: RbySliverAppBar.height(context) + theme.spacing.base,
              child: TweetList(
                state.tweets.toList(),
                loadMore: state.maybeMap(
                  data: (data) => data.hasReachedEnd ? null : notifier.loadMore,
                  orElse: () => null,
                ),
                hasReachedEnd: state.maybeMap(
                  data: (data) => data.hasReachedEnd,
                  orElse: () => true,
                ),
                isLoadingMore: state.maybeMap(
                  data: (data) => false,
                  loading: (_) => true,
                  orElse: () => false,
                ),
                beginSlivers: [
                  SearchAppBar(
                    text: state.query,
                    onSubmitted: (value) => notifier.search(customQuery: value),
                    onClear: notifier.clear,
                    actions: [
                      RbyButton.transparent(
                        icon: state.filter != null
                            ? Icon(
                                Icons.filter_alt,
                                color: theme.colorScheme.primary,
                              )
                            : const Icon(Icons.filter_alt_outlined),
                        onTap: () => _openSearchFilter(
                          context,
                          initialFilter: state.filter,
                          notifier: notifier,
                        ),
                      ),
                    ],
                  ),
                  ...?state.mapOrNull(
                    initial: (_) => [
                      SliverFillInfoMessage(
                        primaryMessage: RbyButton.text(
                          icon: const Icon(Icons.filter_alt_outlined),
                          label: const Text('advanced query'),
                          onTap: () => _openSearchFilter(
                            context,
                            initialFilter: state.filter,
                            notifier: notifier,
                          ),
                        ),
                      ),
                    ],
                    loading: (_) => const [
                      VerticalSpacer.normalSliver,
                      TweetListLoadingSliver(),
                    ],
                    noData: (_) => const [
                      SliverFillInfoMessage(
                        primaryMessage: Text('no posts found'),
                        secondaryMessage: Text(
                          'only posts of the last 7 days can be retrieved',
                        ),
                      ),
                    ],
                    error: (_) => [
                      SliverFillLoadingError(
                        message: const Text('error searching posts'),
                        onRetry: state.filter != null
                            ? () => notifier.search(filter: state.filter)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _openSearchFilter(
  BuildContext context, {
  required TweetSearchFilterData? initialFilter,
  required TweetSearchNotifier notifier,
}) {
  FocusScope.of(context).unfocus();

  context.pushNamed(
    TweetSearchFilter.name,
    extra: {
      'initialFilter': initialFilter,
      // ignore: avoid_types_on_closure_parameters
      'onSaved': (TweetSearchFilterData filter) {
        notifier.search(filter: filter);
      },
    },
  );
}
