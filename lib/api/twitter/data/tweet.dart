import 'package:harpy/api/twitter/data/entity.dart';
import 'package:harpy/api/twitter/data/user.dart';
import 'package:harpy/core/utils/date_utils.dart';
import 'package:json_annotation/json_annotation.dart';

part 'tweet.g.dart';

@JsonSerializable()
class Tweet {
  @JsonKey(name: 'user')
  User user;
  @JsonKey(name: 'entities')
  Entity entity;
  @JsonKey(name: 'truncated')
  bool truncated;
  @JsonKey(name: 'created_at')
  DateTime createdAt;
  @JsonKey(name: 'favorited')
  bool favorited;
  @JsonKey(name: 'id_str')
  String idStr;
  @JsonKey(name: 'in_reply_to_user_id_str')
  String inReplyToUserIdStr;
  @JsonKey(name: 'text')
  String text;
  @JsonKey(name: 'id')
  int id;
  @JsonKey(name: 'retweet_count')
  int retweetCount;
  @JsonKey(name: 'in_reply_to_status_id_str')
  String inReplyToStatusIdStr;
  @JsonKey(name: 'retweeted')
  bool retweeted;
  @JsonKey(name: 'source')
  String source;
  @JsonKey(name: "reply_count")
  int replyCount;
  @JsonKey(name: "favorite_count")
  int favoriteCount;

  Tweet(
      this.user,
      this.entity,
      this.truncated,
      this.createdAt,
      this.favorited,
      this.idStr,
      this.inReplyToUserIdStr,
      this.text,
      this.id,
      this.retweetCount,
      this.inReplyToStatusIdStr,
      this.retweeted,
      this.source,
      this.replyCount,
      this.favoriteCount);

  factory Tweet.fromJson(Map<String, dynamic> json) => _$TweetFromJson(json);

  Map<String, dynamic> toJson() => _$TweetToJson(this);

  @override
  String toString() {
    return 'Tweet{user: $user,\n entity: $entity,\n truncated: $truncated,\n createdAt: $createdAt,\n favorited: $favorited,\n idStr: $idStr,\n inReplyToUserIdStr: $inReplyToUserIdStr,\n text: $text,\n id: $id,\n retweetCount: $retweetCount,\n inReplyToStatusIdStr: $inReplyToStatusIdStr,\n retweeted: $retweeted,\n source: $source,\n replyCount: $replyCount,\n favoriteCount: $favoriteCount}';
  }
}
