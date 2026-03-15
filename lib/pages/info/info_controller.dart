import 'package:aura/bean/dialog/dialog_helper.dart';
import 'package:aura/modules/bangumi/bangumi_item.dart';
import 'package:aura/pages/collect/collect_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:aura/modules/search/plugin_search_module.dart';
import 'package:aura/request/tmdb.dart';
import 'package:mobx/mobx.dart';
import 'package:aura/utils/logger.dart';
import 'package:aura/modules/comments/comment_item.dart';
import 'package:aura/modules/characters/character_item.dart';
import 'package:aura/modules/staff/staff_item.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  final CollectController collectController = Modular.get<CollectController>();
  late BangumiItem bangumiItem;

  @observable
  bool isLoading = false;

  @observable
  var pluginSearchResponseList = ObservableList<PluginSearchResponse>();

  @observable
  var pluginSearchStatus = ObservableMap<String, String>();

  @observable
  var commentsList = ObservableList<CommentItem>();

  @observable
  var characterList = ObservableList<CharacterItem>();

  @observable
  var staffList = ObservableList<StaffFullItem>();

  Future<void> queryBangumiInfoByID(int id, {String type = "init"}) async {
    isLoading = true;
    try {
      final String primaryMediaType = bangumiItem.type == 1 ? 'movie' : 'tv';
      final String fallbackMediaType =
          primaryMediaType == 'tv' ? 'movie' : 'tv';
      BangumiItem? value = await TMDBHTTP.getDetails(
        id,
        mediaType: primaryMediaType,
      );
      value ??= await TMDBHTTP.getDetails(
        id,
        mediaType: fallbackMediaType,
      );
      if (value == null) return;

      if (type == "init") {
        bangumiItem = value;
      } else {
        bangumiItem.summary = value.summary;
        bangumiItem.tags = value.tags;
        bangumiItem.rank = value.rank;
        bangumiItem.airDate = value.airDate;
        bangumiItem.airWeekday = value.airWeekday;
        bangumiItem.alias = value.alias;
        bangumiItem.ratingScore = value.ratingScore;
        bangumiItem.votes = value.votes;
        bangumiItem.votesCount = value.votesCount;
      }
      collectController.updateLocalCollect(bangumiItem);
    } finally {
      isLoading = false;
    }
  }

  Future<void> queryBangumiCommentsByID(int id, {int offset = 0}) async {
    if (offset == 0) {
      commentsList.clear();
    }
    final String mediaType = bangumiItem.type == 1 ? 'movie' : 'tv';
    final list =
        await TMDBHTTP.getReviews(id, mediaType: mediaType, offset: offset);
    commentsList.addAll(list);
    KazumiLogger().i('InfoController: loaded comments list length ${commentsList.length}');
  }

  Future<void> queryBangumiCharactersByID(int id) async {
    characterList.clear();
    final String mediaType = bangumiItem.type == 1 ? 'movie' : 'tv';
    final list = await TMDBHTTP.getCharacters(id, mediaType: mediaType);
    characterList.addAll(list);
    Map<String, int> relationValue = {
      '主角': 1,
      '配角': 2,
      '客串': 3,
    };

    try {
      characterList.sort((a, b) {
        int valueA = relationValue[a.relation] ?? 4;
        int valueB = relationValue[b.relation] ?? 4;
        return valueA.compareTo(valueB);
      });
    } catch (e) {
      KazumiDialog.showToast(message: '$e');
    }
    KazumiLogger().i('InfoController: loaded character list length ${characterList.length}');
  }

  Future<void> queryBangumiStaffsByID(int id) async {
    staffList.clear();
    final String mediaType = bangumiItem.type == 1 ? 'movie' : 'tv';
    final list = await TMDBHTTP.getStaffs(id, mediaType: mediaType);
    staffList.addAll(list);
    KazumiLogger().i('InfoController: loaded staff list length ${staffList.length}');
  }
}
