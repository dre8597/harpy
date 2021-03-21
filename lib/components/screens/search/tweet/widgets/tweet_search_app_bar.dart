import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/harpy_widgets/harpy_widgets.dart';

/// Builds a sliver app bar for the [TweetSearchScreen] with a [SearchTextField]
/// in the title.
class TweetSearchAppBar extends StatelessWidget {
  const TweetSearchAppBar({
    this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final TweetSearchBloc bloc = context.watch<TweetSearchBloc>();
    final TweetSearchFilterModel model =
        context.watch<TweetSearchFilterModel>();

    return HarpySliverAppBar(
      titleWidget: Container(
        child: SearchTextField(
          text: text,
          hintText: 'search tweets',
          onSubmitted: (String text) =>
              bloc.add(SearchTweets(customQuery: text)),
          onClear: () {
            bloc.add(const ClearSearchResult());
            model.clear();
          },
        ),
      ),
      actions: <Widget>[
        HarpyButton.flat(
          padding: const EdgeInsets.all(16),
          icon: const Icon(Icons.filter_alt_outlined),
          onTap: () {
            // unfocus search field before opening drawer
            final FocusScopeNode currentFocus = FocusScope.of(context);

            if (!currentFocus.hasPrimaryFocus &&
                currentFocus.focusedChild != null) {
              FocusManager.instance.primaryFocus.unfocus();
            }

            Scaffold.of(context).openEndDrawer();
          },
        ),
      ],
      floating: true,
    );
  }
}
