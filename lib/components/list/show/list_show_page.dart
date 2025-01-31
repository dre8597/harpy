import 'package:flutter/material.dart';
import 'package:harpy/api/bluesky/data/list_data.dart';
import 'package:harpy/components/components.dart';

/// Shows an overview of available Twitter lists for the [handle].
class ListShowPage extends StatelessWidget {
  const ListShowPage({
    required this.handle,
    this.onListSelected,
  });

  final String handle;

  /// An optional callback that is called when a list is selected.
  final ValueChanged<BlueskyListData>? onListSelected;

  static const name = 'list_show';

  @override
  Widget build(BuildContext context) {
    return HarpyScaffold(
      child: ScrollDirectionListener(
        child: ScrollToTop(
          child: TwitterLists(
            handle: handle,
            onListSelected: onListSelected,
          ),
        ),
      ),
    );
  }
}
