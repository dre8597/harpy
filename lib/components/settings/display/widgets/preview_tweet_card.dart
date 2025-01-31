import 'package:bluesky/core.dart';
import 'package:flutter/material.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';

class PreviewTweetCard extends StatelessWidget {
  const PreviewTweetCard({
    this.text = '''
Thank you for using harpy!

Make sure to follow @harpy_app for news and updates about the app''',
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final tweet = BlueskyPostData(
      handle: 'harpy_app',
      id: '1068105113284300800',
      media: const [
        BlueskyMediaData(
          url:
              'https://pbs.twimg.com/profile_images/1356691241140957190/N03_GPid_400x400.jpg',
          alt: '',
        ),
      ],
      text: text,
      mentions: const ['harpy_app'],
      createdAt: DateTime.now(),
      uri: const AtUri(''),
      author: 'harpy',
      authorDid: 'harpy',
      authorAvatar:
          'https://pbs.twimg.com/profile_images/1356691241140957190/N03_GPid_400x400.jpg',
    );

    return TweetCard(
      tweet: tweet,
      createDelegates: (_, __) => const TweetDelegates(),
    );
  }
}
