import 'package:shared_preferences/shared_preferences.dart';

class AudioFavoritesManager {
  static const String _favoritesKey = 'audio_favorites';

  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  static Future<bool> isFavorite(String url) async {
    final favorites = await getFavorites();
    return favorites.contains(url);
  }

  static Future<void> toggleFavorite(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();

    if (favorites.contains(url)) {
      favorites.remove(url);
    } else {
      favorites.add(url);
    }

    await prefs.setStringList(_favoritesKey, favorites);
  }
}
