// lib/main_token_dump_v2.dart
import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() => runApp(const TokenDumpV2App());

class TokenDumpV2App extends StatelessWidget {
  const TokenDumpV2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Token Dump V2',
      theme: ThemeData.dark(useMaterial3: true),
      home: const TokenDumpV2Page(),
    );
  }
}

class TokenDumpV2Page extends StatefulWidget {
  const TokenDumpV2Page({super.key});

  @override
  State<TokenDumpV2Page> createState() => _TokenDumpV2PageState();
}

class _TokenDumpV2PageState extends State<TokenDumpV2Page> {
  static const keysToCheck = <String>[
    'bg_access_token',
    'bg_refresh_token',
    'bg_access_expires_at',
    'bg_refresh_expires_at',
    'auth_token',
    'bikergram_tokens_v1',
  ];

  final _secure = const FlutterSecureStorage();

  String _status = '—';
  Map<String, String?> _sp = {};
  Map<String, String?> _sec = {};
  List<String> _spAllKeys = [];
  List<String> _lsAllKeys = [];
  List<String> _lsTokenKeys = [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  String _short(String? s) {
    if (s == null) return 'null';
    final t = s.trim();
    if (t.isEmpty) return '(empty)';
    if (t.length <= 18) return t;
    return '${t.substring(0, 10)}...${t.substring(t.length - 6)}';
  }

  Future<void> _loadAll() async {
    setState(() => _status = 'loading...');

    // SharedPreferences
    final sp = await SharedPreferences.getInstance();
    final spMap = <String, String?>{};
    for (final k in keysToCheck) {
      spMap[k] = sp.getString(k);
    }
    final spKeys = sp.getKeys().toList()..sort();

    // FlutterSecureStorage
    final secMap = <String, String?>{};
    for (final k in keysToCheck) {
      secMap[k] = await _secure.read(key: k);
    }

    // Browser LocalStorage (roh)
    final lsKeys = <String>[];
    for (final k in html.window.localStorage.keys) {
      lsKeys.add(k);
    }
    lsKeys.sort();

    final tokenLike = lsKeys
        .where((k) =>
            k.toLowerCase().contains('bg_') ||
            k.toLowerCase().contains('token') ||
            k.toLowerCase().contains('secure') ||
            k.toLowerCase().contains('flutter_secure_storage') ||
            k.toLowerCase().contains('bikergram'))
        .toList();

    setState(() {
      _sp = spMap;
      _sec = secMap;
      _spAllKeys = spKeys;
      _lsAllKeys = lsKeys;
      _lsTokenKeys = tokenLike;
      _status = 'loaded';
    });
  }

  Future<void> _clearTokens() async {
    setState(() => _status = 'clearing...');

    final sp = await SharedPreferences.getInstance();

    for (final k in keysToCheck) {
      await sp.remove(k);
      await _secure.delete(key: k);
    }

    // Nur "token-artige" LocalStorage Keys löschen (nicht alles!)
    for (final k in List<String>.from(html.window.localStorage.keys)) {
      final kl = k.toLowerCase();
      final isTokenKey = kl.contains('bg_') ||
          kl.contains('token') ||
          kl.contains('secure') ||
          kl.contains('flutter_secure_storage') ||
          kl.contains('bikergram');
      if (isTokenKey) {
        html.window.localStorage.remove(k);
      }
    }

    await _loadAll();
    setState(() => _status = 'cleared');
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _kvCard(String key, String? val) => Card(
        child: ListTile(
          title: Text(key, style: const TextStyle(fontFamily: 'monospace')),
          subtitle: Text(_short(val), style: const TextStyle(fontFamily: 'monospace')),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final origin = Uri.base.origin;
    final href = Uri.base.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('TOKEN DUMP V2')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: ListView(
          children: [
            Text('Origin: $origin', style: const TextStyle(fontFamily: 'monospace')),
            Text('URL:    $href', style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 10),
            Text('Status: $_status'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loadAll,
                    child: const Text('RELOAD'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearTokens,
                    child: const Text('CLEAR TOKENS'),
                  ),
                ),
              ],
            ),

            _sectionTitle('1) SharedPreferences (Flutter)'),
            ...keysToCheck.map((k) => _kvCard(k, _sp[k])),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _spAllKeys.isEmpty ? 'SP keys: — keine —' : 'SP keys (${_spAllKeys.length}):\n${_spAllKeys.join('\n')}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),

            _sectionTitle('2) FlutterSecureStorage'),
            ...keysToCheck.map((k) => _kvCard(k, _sec[k])),

            _sectionTitle('3) Browser LocalStorage (nur “tokenartige” Keys)'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _lsTokenKeys.isEmpty
                      ? 'LocalStorage token keys: — keine —'
                      : 'LocalStorage token keys (${_lsTokenKeys.length}):\n${_lsTokenKeys.join('\n')}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),

            _sectionTitle('4) Browser LocalStorage (alle Keys)'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _lsAllKeys.isEmpty ? 'LocalStorage keys: — keine —' : 'LocalStorage keys (${_lsAllKeys.length}):\n${_lsAllKeys.join('\n')}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
