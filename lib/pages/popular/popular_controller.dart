import 'package:flutter/material.dart';
import 'package:aura/request/tmdb.dart';
import 'package:aura/modules/bangumi/bangumi_item.dart';
import 'package:aura/utils/constants.dart';
import 'package:mobx/mobx.dart';

part 'popular_controller.g.dart';

class PopularController = _PopularController with _$PopularController;

abstract class _PopularController with Store {
  final ScrollController scrollController = ScrollController();

  @observable
  String currentTag = '';

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  @observable
  ObservableList<BangumiItem> trendList = ObservableList.of([]);

  double scrollOffset = 0.0;

  @observable
  bool isLoadingMore = false;

  @observable
  bool isTimeOut = false;

  void setCurrentTag(String s) {
    currentTag = s;
  }

  void clearBangumiList() {
    bangumiList.clear();
  }

  Future<void> queryBangumiByTrend({String type = 'add'}) async {
    if (type == 'init') {
      trendList.clear();
    }
    isLoadingMore = true;
    var result = await TMDBHTTP.getTrendingTv(offset: trendList.length);
    trendList.addAll(result);
    isLoadingMore = false;
    isTimeOut = trendList.isEmpty;
  }

  Future<void> queryBangumiByTag({String type = 'add'}) async {
    if (type == 'init') {
      bangumiList.clear();
    }
    isLoadingMore = true;
    var tag = currentTag;
    final filter = exploreTagFilters[tag];
    final withGenres = filter?['with_genres'];
    final withOriginalLanguage = filter?['with_original_language'];

    final List<BangumiItem> result = filter == null
        ? await TMDBHTTP.searchTvMovie(tag, offset: bangumiList.length)
        : await TMDBHTTP.discoverTv(
            offset: bangumiList.length,
            withGenres: withGenres,
            withOriginalLanguage: withOriginalLanguage,
          );
    bangumiList.addAll(result);
    isLoadingMore = false;
    isTimeOut = bangumiList.isEmpty;
  }
}
