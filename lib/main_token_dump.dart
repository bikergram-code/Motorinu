import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const TokenDumpApp());

class TokenDumpApp extends StatelessWidget {
  const TokenDumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bikergram Token Dump',
      theme: ThemeData.dark(useMaterial3: true),
      home: const TokenDumpPage(),
    );
  }
}

class TokenDumpPage extends StatefulWidget {
  const TokenDumpPage({super.key});

  @override
  State<TokenDumpPage> createState() => _TokenDumpPageState();
}

class _TokenDumpPageState extends State<TokenDumpPage> {
  Map<String, String?> _values = {};
  List<String> _allKeys = [];
  String _status = '—';

  static const keysToCheck = <String>[
    'bg_access_token',
    'bg_refresh_token',
    'bg_access_expires_at',
    'bg_refresh_expires_at',
    'auth_token',
    'bikergram_tokens_v1',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _short(String? s) {
    if (s == null) return 'null';
    final t = s.trim();
    if (t.isEmpty) return '(empty)';
    if (t.length <= 18) return t;
    return '${t.substring(0, 9)}...${t.substring(t.length - 6)}';
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final map = <String, String?>{};
    for (final k in keysToCheck) {
      map[k] = sp.getString(k);
    }

    setState(() {
      _values = map;
      _allKeys = sp.getKeys().toList()..sort();
      _status = 'loaded';
    });
  }

  Future<void> _clearTokens() async {
    final sp = await SharedPreferences.getInstance();
    for (final k in keysToCheck) {
      await sp.remove(k);
    }
    await _load();
    setState(() => _status = 'cleared');
  }

  @override
  Widget build(BuildContext context) {
    final origin = Uri.base.origin;
    final href = Uri.base.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Dump (SharedPreferences)'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Reload'),
          IconButton(onPressed: _clearTokens, icon: const Icon(Icons.delete), tooltip: 'Clear tokens'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: ListView(
          children: [
            Text('Origin: $origin', style: const TextStyle(fontFamily: 'monospace')),
            Text('URL:    $href', style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 10),
            Text('Status: $_status'),
            const SizedBox(height: 16),

            const Text('Wichtige Keys:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...keysToCheck.map((k) {
              final v = _values[k];
              return Card(
                child: ListTile(
                  title: Text(k, style: const TextStyle(fontFamily: 'monospace')),
                  subtitle: Text(_short(v), style: const TextStyle(fontFamily: 'monospace')),
                ),
              );
            }),

            const SizedBox(height: 16),
            Text('Alle Keys (${_allKeys.length}):', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _allKeys.isEmpty ? '— keine —' : _allKeys.join('\n'),
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
