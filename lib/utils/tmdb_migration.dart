import 'package:aura/request/tmdb.dart';
import 'package:aura/utils/logger.dart';
import 'package:aura/utils/storage.dart';
import 'package:aura/utils/string_match.dart';
import 'package:aura/modules/collect/collect_module.dart';
import 'package:aura/modules/history/history_module.dart';
import 'package:aura/modules/bangumi/bangumi_item.dart';
import 'package:aura/config/tmdb_config.dart';

class TmdbMigration {
  static Future<void> migrateIfNeeded({int maxItems = 50}) async {
    final done =
        GStorage.setting.get(SettingBoxKey.tmdbMigrationDone, defaultValue: false)
            as bool;
    if (done) return;
    if (TmdbConfig.proxyBase.trim().isEmpty && TmdbConfig.readToken.isEmpty) {
      return;
    }

    try {
      final migratedCollect = await _migrateCollectibles(maxItems: maxItems);
      final migratedHistory = await _migrateHistories(maxItems: maxItems);
      if (!migratedCollect && !migratedHistory) {
        await GStorage.setting.put(SettingBoxKey.tmdbMigrationDone, true);
      }
    } catch (e) {
      KazumiLogger().w('TMDB: migration failed', error: e);
    }
  }

  static String _pickTitle(String nameCn, String name) {
    final t = nameCn.trim().isNotEmpty ? nameCn.trim() : name.trim();
    return t;
  }

  static double _scoreTitle(String query, String candidateCn, String candidate) {
    final q = query.toLowerCase();
    final a = candidateCn.toLowerCase();
    final b = candidate.toLowerCase();
    final s1 = calculateSimilarity(q, a);
    final s2 = calculateSimilarity(q, b);
    return s1 > s2 ? s1 : s2;
  }

  static Future<bool> _migrateCollectibles({required int maxItems}) async {
    int migrated = 0;
    final entries = GStorage.collectibles.toMap().entries.toList();
    for (final entry in entries) {
      if (migrated >= maxItems) return true;

      final oldKey = entry.key;
      final item = entry.value;
      final title = _pickTitle(item.bangumiItem.nameCn, item.bangumiItem.name);
      if (title.isEmpty) continue;

      final primaryType = item.bangumiItem.type == 1 ? 'movie' : 'tv';
      final fallbackType = primaryType == 'tv' ? 'movie' : 'tv';
      final id = item.bangumiItem.id;

      final exists =
          await TMDBHTTP.getDetails(id, mediaType: primaryType) ??
              await TMDBHTTP.getDetails(id, mediaType: fallbackType);
      if (exists != null) {
        continue;
      }

      final candidates = await TMDBHTTP.searchTvMovie(title, offset: 0);
      if (candidates.isEmpty) continue;

      BangumiItem? best;
      double bestScore = 0.0;
      for (final c in candidates) {
        final score = _scoreTitle(title, c.nameCn, c.name);
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }
      if (best == null || bestScore < 0.6) continue;

      final mediaType = best.type == 1 ? 'movie' : 'tv';
      final details = await TMDBHTTP.getDetails(best.id, mediaType: mediaType);
      final newBangumiItem = details ?? best;
      final newCollected =
          CollectedBangumi(newBangumiItem, item.time, item.type);

      await GStorage.tmdbCollectiblesBackup.put(oldKey, item);
      await GStorage.collectibles.put(newBangumiItem.id, newCollected);
      await GStorage.collectibles.delete(oldKey);

      migrated++;
    }
    return migrated > 0;
  }

  static Future<bool> _migrateHistories({required int maxItems}) async {
    int migrated = 0;
    final entries = GStorage.histories.toMap().entries.toList();
    for (final entry in entries) {
      if (migrated >= maxItems) return true;

      final oldKey = entry.key;
      final history = entry.value;
      final title =
          _pickTitle(history.bangumiItem.nameCn, history.bangumiItem.name);
      if (title.isEmpty) continue;

      final primaryType = history.bangumiItem.type == 1 ? 'movie' : 'tv';
      final fallbackType = primaryType == 'tv' ? 'movie' : 'tv';
      final id = history.bangumiItem.id;

      final exists =
          await TMDBHTTP.getDetails(id, mediaType: primaryType) ??
              await TMDBHTTP.getDetails(id, mediaType: fallbackType);
      if (exists != null) {
        continue;
      }

      final candidates = await TMDBHTTP.searchTvMovie(title, offset: 0);
      if (candidates.isEmpty) continue;

      BangumiItem? best;
      double bestScore = 0.0;
      for (final c in candidates) {
        final score = _scoreTitle(title, c.nameCn, c.name);
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }
      if (best == null || bestScore < 0.6) continue;

      final mediaType = best.type == 1 ? 'movie' : 'tv';
      final details = await TMDBHTTP.getDetails(best.id, mediaType: mediaType);
      final newBangumiItem = details ?? best;

      final newHistory = History(
        newBangumiItem,
        history.lastWatchEpisode,
        history.adapterName,
        history.lastWatchTime,
        history.lastSrc,
        history.lastWatchEpisodeName,
      );
      newHistory.progresses = history.progresses;

      final newKey = History.getKey(history.adapterName, newBangumiItem);

      await GStorage.tmdbHistoriesBackup.put(oldKey, history);
      await GStorage.histories.put(newKey, newHistory);
      await GStorage.histories.delete(oldKey);

      migrated++;
    }
    return migrated > 0;
  }
}
