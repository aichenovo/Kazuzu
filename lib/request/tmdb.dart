import 'package:aura/request/api.dart';
import 'package:aura/request/request.dart';
import 'package:aura/bean/dialog/dialog_helper.dart';
import 'package:aura/utils/logger.dart';
import 'package:aura/utils/utils.dart';
import 'package:aura/modules/bangumi/bangumi_item.dart';
import 'package:aura/modules/bangumi/bangumi_tag.dart';
import 'package:aura/modules/comments/comment_item.dart';
import 'package:aura/modules/characters/character_item.dart';
import 'package:aura/modules/characters/actor_item.dart';
import 'package:aura/modules/staff/staff_item.dart';
import 'package:aura/config/tmdb_config.dart';

class TMDBHTTP {
  static bool _missingConfigToastShown = false;

  static String _normalizeBase(String base) {
    final b = base.trim();
    if (b.isEmpty) return '';
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  static bool get isConfigured {
    if (_normalizeBase(TmdbConfig.proxyBase).isNotEmpty) return true;
    return TmdbConfig.readToken.trim().isNotEmpty;
  }

  static bool _ensureConfigured() {
    if (isConfigured) return true;
    if (!_missingConfigToastShown) {
      _missingConfigToastShown = true;
      KazumiDialog.showToast(message: 'TMDB 服务未配置，请联系开发者');
    }
    return false;
  }

  static String get base {
    final proxy = _normalizeBase(TmdbConfig.proxyBase);
    if (proxy.isNotEmpty) return '$proxy${Api.tmdbAPIVersionPath}';
    return Api.tmdbAPIDomain + Api.tmdbAPIVersionPath;
  }
  static const String _imageBase = 'https://image.tmdb.org/t/p/';


  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toFixed1Double(dynamic value) {
    final num n = (value is num) ? value : (num.tryParse(value?.toString() ?? '') ?? 0);
    return double.tryParse(n.toDouble().toStringAsFixed(1)) ?? 0.0;
  }

  static int _parseIsoToSeconds(dynamic iso) {
    if (iso == null) return 0;
    final parsed = DateTime.tryParse(iso.toString());
    if (parsed == null) return 0;
    return (parsed.millisecondsSinceEpoch / 1000).round();
  }

  static String _imageUrl(String size, String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('/http')) return path.substring(1);
    return '$_imageBase$size$path';
  }

  static Map<String, String> _imagesFromPaths({
    required String? posterPath,
    required String? backdropPath,
  }) {
    final String? bestPath = (posterPath != null && posterPath.isNotEmpty)
        ? posterPath
        : ((backdropPath != null && backdropPath.isNotEmpty) ? backdropPath : null);

    if (bestPath == null) {
      return {
        'large': '',
        'common': '',
        'medium': '',
        'small': '',
        'grid': '',
      };
    }

    return {
      'large': _imageUrl('w500', bestPath),
      'common': _imageUrl('w342', bestPath),
      'medium': _imageUrl('w185', bestPath),
      'small': _imageUrl('w92', bestPath),
      'grid': _imageUrl('w154', bestPath),
    };
  }

  static List<BangumiTag> _tagsFromGenres(dynamic genres) {
    if (genres is! List) return [];
    final List<BangumiTag> tags = [];
    for (final g in genres) {
      if (g is Map<String, dynamic>) {
        final name = (g['name'] ?? '').toString();
        if (name.isNotEmpty) {
          tags.add(BangumiTag(name: name, count: 0, totalCount: _toInt(g['id'])));
        }
      }
    }
    return tags;
  }

  static List<String> _buildAlias({
    required String? localizedTitle,
    required String? originalTitle,
    dynamic alternativeTitles,
  }) {
    final Set<String> set = {};
    if (localizedTitle != null && localizedTitle.trim().isNotEmpty) {
      set.add(localizedTitle.trim());
    }
    if (originalTitle != null && originalTitle.trim().isNotEmpty) {
      set.add(originalTitle.trim());
    }

    dynamic results = alternativeTitles;
    if (alternativeTitles is Map<String, dynamic>) {
      results = alternativeTitles['results'];
    }

    if (results is List) {
      for (final item in results) {
        if (item is Map<String, dynamic>) {
          final title = (item['title'] ?? '').toString().trim();
          if (title.isNotEmpty) {
            set.add(title);
          }
        }
      }
    }

    return set.toList();
  }

  static BangumiItem _itemFromSearchResult(Map<String, dynamic> json) {
    final mediaType = (json['media_type'] ?? '').toString();
    final bool isTv = mediaType == 'tv';
    final int type = isTv ? 2 : 1;

    final localizedName =
        (isTv ? json['name'] : json['title'])?.toString() ?? '';
    final originalName =
        (isTv ? json['original_name'] : json['original_title'])?.toString() ??
            '';
    final nameCn = localizedName.isNotEmpty ? localizedName : originalName;

    final String airDate =
        (isTv ? json['first_air_date'] : json['release_date'])?.toString() ??
            '';

    return BangumiItem(
      id: _toInt(json['id']),
      type: type,
      name: originalName,
      nameCn: nameCn,
      summary: (json['overview'] ?? '').toString(),
      airDate: airDate,
      airWeekday: Utils.dateStringToWeekday(
        airDate.isNotEmpty ? airDate : '2000-11-11',
      ),
      rank: 0,
      images: _imagesFromPaths(
        posterPath: json['poster_path']?.toString(),
        backdropPath: json['backdrop_path']?.toString(),
      ),
      tags: const [],
      alias: _buildAlias(localizedTitle: nameCn, originalTitle: originalName),
      ratingScore: _toFixed1Double(json['vote_average']),
      votes: _toInt(json['vote_count']),
      votesCount: const [],
      info: '',
    );
  }

  static BangumiItem _itemFromDetails(Map<String, dynamic> json,
      {required String mediaType}) {
    final bool isTv = mediaType == 'tv';
    final int type = isTv ? 2 : 1;

    final localizedName =
        (isTv ? json['name'] : json['title'])?.toString() ?? '';
    final originalName =
        (isTv ? json['original_name'] : json['original_title'])?.toString() ??
            '';
    final nameCn = localizedName.isNotEmpty ? localizedName : originalName;
    final String airDate =
        (isTv ? json['first_air_date'] : json['release_date'])?.toString() ??
            '';

    return BangumiItem(
      id: _toInt(json['id']),
      type: type,
      name: originalName,
      nameCn: nameCn,
      summary: (json['overview'] ?? '').toString(),
      airDate: airDate,
      airWeekday: Utils.dateStringToWeekday(
        airDate.isNotEmpty ? airDate : '2000-11-11',
      ),
      rank: 0,
      images: _imagesFromPaths(
        posterPath: json['poster_path']?.toString(),
        backdropPath: json['backdrop_path']?.toString(),
      ),
      tags: _tagsFromGenres(json['genres']),
      alias: _buildAlias(
        localizedTitle: nameCn,
        originalTitle: originalName,
        alternativeTitles: json['alternative_titles'],
      ),
      ratingScore: _toFixed1Double(json['vote_average']),
      votes: _toInt(json['vote_count']),
      votesCount: const [],
      info: '',
    );
  }

  static Future<List<BangumiItem>> searchTvMovie(
    String keyword, {
    int offset = 0,
    String language = 'zh-CN',
  }) async {
    if (!_ensureConfigured()) return [];
    final int page = (offset ~/ 20) + 1;
    final params = <String, dynamic>{
      'query': keyword,
      'include_adult': false,
      'language': language,
      'page': page,
    };

    try {
      final res = await Request().get(
        '$base/search/multi',
        data: params,
        extra: {'customError': 'TMDB：搜索失败'},
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return [];
      final results = data['results'];
      if (results is! List) return [];

      final List<BangumiItem> list = [];
      for (final item in results) {
        if (item is Map<String, dynamic>) {
          final mediaType = (item['media_type'] ?? '').toString();
          if (mediaType == 'tv' || mediaType == 'movie') {
            list.add(_itemFromSearchResult(item));
          }
        }
      }
      return list;
    } catch (e) {
      KazumiLogger().e('TMDB: resolve search results failed', error: e);
      return [];
    }
  }

  static Future<BangumiItem?> getDetails(
    int id, {
    required String mediaType,
    String language = 'zh-CN',
  }) async {
    if (!_ensureConfigured()) return null;
    final params = <String, dynamic>{
      'language': language,
      'append_to_response': 'credits,images,reviews,alternative_titles',
      'include_image_language': 'en,null',
    };

    try {
      final res = await Request().get(
        '$base/$mediaType/$id',
        data: params,
        extra: {'customError': 'TMDB：获取详情失败'},
      );
      if (res.data is! Map<String, dynamic>) return null;
      return _itemFromDetails(
        Map<String, dynamic>.from(res.data as Map),
        mediaType: mediaType,
      );
    } catch (e) {
      KazumiLogger().e('TMDB: resolve details failed', error: e);
      return null;
    }
  }

  static Future<List<BangumiItem>> getTrendingTv({
    int offset = 0,
    String language = 'zh-CN',
  }) async {
    if (!_ensureConfigured()) return [];
    final int page = (offset ~/ 20) + 1;
    final params = <String, dynamic>{
      'language': language,
      'page': page,
    };

    try {
      final res = await Request().get(
        '$base/trending/tv/week',
        data: params,
        extra: {'customError': 'TMDB：获取趋势失败'},
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return [];
      final results = data['results'];
      if (results is! List) return [];

      final List<BangumiItem> list = [];
      for (final item in results) {
        if (item is Map<String, dynamic>) {
          final fixed = Map<String, dynamic>.from(item);
          fixed['media_type'] = 'tv';
          list.add(_itemFromSearchResult(fixed));
        }
      }
      return list;
    } catch (e) {
      KazumiLogger().e('TMDB: resolve trending failed', error: e);
      return [];
    }
  }

  static Future<List<BangumiItem>> discoverTvByDateRange(
    List<String> dateRange, {
    int offset = 0,
    String language = 'zh-CN',
  }) async {
    if (!_ensureConfigured()) return [];
    final int page = (offset ~/ 20) + 1;
    final params = <String, dynamic>{
      'language': language,
      'page': page,
      'sort_by': 'popularity.desc',
      'first_air_date.gte': dateRange[0],
      'first_air_date.lte': dateRange[1],
      'include_adult': false,
    };

    try {
      final res = await Request().get(
        '$base/discover/tv',
        data: params,
        extra: {'customError': 'TMDB：获取时间线失败'},
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return [];
      final results = data['results'];
      if (results is! List) return [];

      final List<BangumiItem> list = [];
      for (final item in results) {
        if (item is Map<String, dynamic>) {
          final fixed = Map<String, dynamic>.from(item);
          fixed['media_type'] = 'tv';
          list.add(_itemFromSearchResult(fixed));
        }
      }
      return list;
    } catch (e) {
      KazumiLogger().e('TMDB: resolve discover failed', error: e);
      return [];
    }
  }

  static Future<List<BangumiItem>> discoverTv({
    int offset = 0,
    String language = 'zh-CN',
    String sortBy = 'popularity.desc',
    String? withGenres,
    String? withOriginalLanguage,
  }) async {
    if (!_ensureConfigured()) return [];
    final int page = (offset ~/ 20) + 1;
    final params = <String, dynamic>{
      'language': language,
      'page': page,
      'sort_by': sortBy,
      'include_adult': false,
    };

    final genres = (withGenres ?? '').trim();
    if (genres.isNotEmpty) {
      params['with_genres'] = genres;
    }
    final originalLanguage = (withOriginalLanguage ?? '').trim();
    if (originalLanguage.isNotEmpty) {
      params['with_original_language'] = originalLanguage;
    }

    try {
      final res = await Request().get(
        '$base/discover/tv',
        data: params,
        extra: {'customError': 'TMDB：获取发现失败'},
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return [];
      final results = data['results'];
      if (results is! List) return [];

      final List<BangumiItem> list = [];
      for (final item in results) {
        if (item is Map<String, dynamic>) {
          final fixed = Map<String, dynamic>.from(item);
          fixed['media_type'] = 'tv';
          list.add(_itemFromSearchResult(fixed));
        }
      }
      return list;
    } catch (e) {
      KazumiLogger().e('TMDB: resolve discover failed', error: e);
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getWatchProviders(
    int id, {
    required String mediaType,
    String region = 'CN',
  }) async {
    if (!_ensureConfigured()) return null;
    try {
      final res = await Request().get(
        '$base/$mediaType/$id/watch/providers',
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return null;
      final results = data['results'];
      if (results is! Map<String, dynamic>) return null;

      Map<String, dynamic>? regionData;
      if (results[region] is Map<String, dynamic>) {
        regionData = Map<String, dynamic>.from(results[region]);
      } else if (results['US'] is Map<String, dynamic>) {
        regionData = Map<String, dynamic>.from(results['US']);
      } else {
        for (final entry in results.entries) {
          if (entry.value is Map<String, dynamic>) {
            regionData = Map<String, dynamic>.from(entry.value);
            break;
          }
        }
      }
      if (regionData == null) return null;

      final link = (regionData['link'] ?? '').toString();
      final List providers = (regionData['flatrate'] is List)
          ? regionData['flatrate']
          : ((regionData['free'] is List)
              ? regionData['free']
              : ((regionData['ads'] is List)
                  ? regionData['ads']
                  : ((regionData['buy'] is List)
                      ? regionData['buy']
                      : ((regionData['rent'] is List)
                          ? regionData['rent']
                          : const []))));

      final list = <Map<String, String>>[];
      for (final p in providers) {
        if (p is Map<String, dynamic>) {
          final name = (p['provider_name'] ?? '').toString();
          final logoPath = (p['logo_path'] ?? '').toString();
          if (name.isEmpty) continue;
          list.add({
            'name': name,
            'logo': _imageUrl('w92', logoPath),
          });
        }
      }

      return {
        'link': link,
        'providers': list,
      };
    } catch (e) {
      KazumiLogger().e('TMDB: resolve watch providers failed', error: e);
      return null;
    }
  }

  static Future<List<CommentItem>> getReviews(
    int id, {
    required String mediaType,
    int offset = 0,
  }) async {
    if (!_ensureConfigured()) return [];
    final int page = (offset ~/ 20) + 1;
    final params = <String, dynamic>{
      'page': page,
    };

    try {
      final res = await Request().get(
        '$base/$mediaType/$id/reviews',
        data: params,
        extra: {'customError': 'TMDB：获取评论失败'},
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return [];
      final results = data['results'];
      if (results is! List) return [];

      final List<CommentItem> list = [];
      for (final item in results) {
        if (item is Map<String, dynamic>) {
          final author = (item['author'] ?? '').toString();
          final content = (item['content'] ?? '').toString();
          final authorDetails = item['author_details'];
          final avatarPath = authorDetails is Map<String, dynamic>
              ? authorDetails['avatar_path']?.toString()
              : null;
          final rating = authorDetails is Map<String, dynamic>
              ? authorDetails['rating']
              : null;
          final ts = _parseIsoToSeconds(item['updated_at'] ?? item['created_at']);
          final avatar = _imageUrl('w185', avatarPath);

          list.add(
            CommentItem(
              user: User(
                id: 0,
                username: author,
                nickname: author,
                avatar: UserAvatar(
                  small: avatar,
                  medium: avatar,
                  large: avatar,
                ),
                sign: '',
                joinedAt: ts,
              ),
              comment: Comment(
                rate: _toInt(rating),
                comment: content,
                updatedAt: ts,
              ),
            ),
          );
        }
      }
      return list;
    } catch (e) {
      KazumiLogger().e('TMDB: resolve reviews failed', error: e);
      return [];
    }
  }

  static Future<List<CharacterItem>> getCharacters(
    int id, {
    required String mediaType,
  }) async {
    if (!_ensureConfigured()) return [];
    try {
      final res = await Request().get(
        '$base/$mediaType/$id/credits',
        extra: {'customError': 'TMDB：获取角色失败'},
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return [];
      final cast = data['cast'];
      if (cast is! List) return [];

      final List<CharacterItem> list = [];
      for (final item in cast) {
        if (item is Map<String, dynamic>) {
          final order = _toInt(item['order']);
          final relation = order < 5 ? '主角' : '配角';
          final profilePath = item['profile_path']?.toString();
          final personId = _toInt(item['id']);
          final personName = (item['name'] ?? '').toString();
          final characterName = (item['character'] ?? '').toString();
          final avatar = _imageUrl('w185', profilePath);

          list.add(
            CharacterItem(
              id: personId,
              type: 0,
              name: characterName.isNotEmpty ? characterName : personName,
              relation: relation,
              avator: CharacterAvator(
                small: _imageUrl('w45', profilePath),
                medium: avatar,
                grid: avatar,
                large: _imageUrl('w342', profilePath),
              ),
              actorList: [
                ActorItem(
                  id: personId,
                  type: 0,
                  name: personName,
                  avator: ActorAvator(
                    small: _imageUrl('w45', profilePath),
                    medium: avatar,
                    grid: avatar,
                    large: _imageUrl('w342', profilePath),
                  ),
                ),
              ],
              info: CharacterExtraInfo(nameCn: '', summary: ''),
            ),
          );
        }
      }
      return list;
    } catch (e) {
      KazumiLogger().e('TMDB: resolve credits cast failed', error: e);
      return [];
    }
  }

  static Future<List<StaffFullItem>> getStaffs(
    int id, {
    required String mediaType,
  }) async {
    if (!_ensureConfigured()) return [];
    try {
      final res = await Request().get(
        '$base/$mediaType/$id/credits',
        extra: {'customError': 'TMDB：获取制作人员失败'},
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return [];
      final crew = data['crew'];
      if (crew is! List) return [];

      final List<StaffFullItem> list = [];
      for (final item in crew) {
        if (item is Map<String, dynamic>) {
          final profilePath = item['profile_path']?.toString();
          final img = _imageUrl('w185', profilePath);
          final staffId = _toInt(item['id']);
          final staffName = (item['name'] ?? '').toString();
          final job = (item['job'] ?? '').toString();

          list.add(
            StaffFullItem(
              staff: Staff(
                id: staffId,
                name: staffName,
                nameCN: '',
                type: 0,
                info: '',
                comment: 0,
                lock: false,
                nsfw: false,
                images: Images(
                  large: _imageUrl('w342', profilePath),
                  medium: img,
                  small: _imageUrl('w45', profilePath),
                  grid: img,
                ),
              ),
              positions: [
                Position(
                  type: PositionType(id: 0, en: job, cn: job, jp: ''),
                  summary: '',
                  appearEps: '',
                ),
              ],
            ),
          );
        }
      }
      return list;
    } catch (e) {
      KazumiLogger().e('TMDB: resolve credits crew failed', error: e);
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getPersonDetails(
    int personId, {
    String language = 'zh-CN',
  }) async {
    if (!_ensureConfigured()) return null;
    final params = <String, dynamic>{
      'language': language,
    };

    try {
      final res = await Request().get(
        '$base/person/$personId',
        data: params,
        extra: {'customError': 'TMDB：获取人物信息失败'},
      );
      if (res.data is! Map<String, dynamic>) return null;
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      KazumiLogger().e('TMDB: resolve person details failed', error: e);
      return null;
    }
  }
}
