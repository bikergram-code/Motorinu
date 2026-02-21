import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/saved_place.dart';

const _storageKey = 'blitzer_saved_places';
const _maxPlaces = 20;

final savedPlacesProvider =
    NotifierProvider<SavedPlacesNotifier, List<SavedPlace>>(
        SavedPlacesNotifier.new);

class SavedPlacesNotifier extends Notifier<List<SavedPlace>> {
  @override
  List<SavedPlace> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final places = <SavedPlace>[];
      for (final s in raw) {
        try {
          places.add(SavedPlace.fromJson(
              jsonDecode(s) as Map<String, dynamic>));
        } catch (_) {}
      }
      state = places;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = state.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  /// Zuhause-Ort abrufen (kann null sein)
  SavedPlace? get home =>
      state.where((p) => p.id == 'home').firstOrNull;

  /// Arbeitsort abrufen (kann null sein)
  SavedPlace? get work =>
      state.where((p) => p.id == 'work').firstOrNull;

  /// Ort hinzufügen oder aktualisieren (by id)
  Future<void> setPlace(SavedPlace place) async {
    final existing = state.indexWhere((p) => p.id == place.id);
    if (existing >= 0) {
      state = [...state]..[existing] = place;
    } else {
      if (state.length >= _maxPlaces) return; // Limit
      state = [place, ...state];
    }
    await _persist();
  }

  /// Ort entfernen
  Future<void> removePlace(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _persist();
  }

  /// Zuhause setzen
  Future<void> setHome({
    required String address,
    required double lat,
    required double lng,
  }) async {
    await setPlace(SavedPlace(
      id: 'home',
      name: 'Zuhause',
      address: address,
      lat: lat,
      lng: lng,
      icon: 'home',
    ));
  }

  /// Arbeit setzen
  Future<void> setWork({
    required String address,
    required double lat,
    required double lng,
  }) async {
    await setPlace(SavedPlace(
      id: 'work',
      name: 'Arbeit',
      address: address,
      lat: lat,
      lng: lng,
      icon: 'work',
    ));
  }
}
