import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:harpy/components/components.dart';
import 'package:intl/intl.dart' as intl;
import 'package:rby/rby.dart';

class TrendCard extends StatelessWidget {
  const TrendCard({
    required this.trend,
  });

  final Trend trend;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final numberFormat = intl.NumberFormat.compact(locale: locale);

    return RbyListCard(
      leading: const Icon(FeatherIcons.trendingUp, size: 18),
      title: Text(
        trend.name,
        textDirection: TextDirection.ltr,
      ),
      subtitle: Text('${numberFormat.format(trend.postCount)} tweets'),
      onTap: () => context.pushNamed(
        TweetSearchPage.name,
        queryParameters: {'query': trend.name},
      ),
    );
  }
}
