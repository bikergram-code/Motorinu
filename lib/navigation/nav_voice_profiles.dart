// Voice profiles for navigation TTS — transform standard German instructions
// into personality-flavored text (Pirat, Biker, Roboter, Opa, Feldwebel).

class NavVoiceProfile {
  final String id;
  final String name;
  final String icon;
  final String description;
  final double pitch;
  final double rate;
  final String Function(String baseText) transform;

  const NavVoiceProfile({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.pitch,
    required this.rate,
    required this.transform,
  });
}

/// All available voice profiles.
final Map<String, NavVoiceProfile> navVoiceProfiles = {
  'standard': NavVoiceProfile(
    id: 'standard',
    name: 'Standard',
    icon: 'record_voice_over',
    description: 'Klare Navigationsansage',
    pitch: 1.0,
    rate: 0.5,
    transform: (t) => t,
  ),
  'pirat': NavVoiceProfile(
    id: 'pirat',
    name: 'Pirat',
    icon: 'sailing',
    description: 'Arrr! Auf zur Schatzsuche!',
    pitch: 0.8,
    rate: 0.45,
    transform: _piratTransform,
  ),
  'biker': NavVoiceProfile(
    id: 'biker',
    name: 'Biker',
    icon: 'two_wheeler',
    description: 'Ride on, Bruder!',
    pitch: 0.7,
    rate: 0.5,
    transform: _bikerTransform,
  ),
  'robot': NavVoiceProfile(
    id: 'robot',
    name: 'Roboter',
    icon: 'smart_toy',
    description: 'Beep boop. Ziel berechnet.',
    pitch: 0.3,
    rate: 0.55,
    transform: _robotTransform,
  ),
  'opa': NavVoiceProfile(
    id: 'opa',
    name: 'Opa',
    icon: 'elderly',
    description: 'Immer langsam, mein Junge!',
    pitch: 0.85,
    rate: 0.4,
    transform: _opaTransform,
  ),
  'drill': NavVoiceProfile(
    id: 'drill',
    name: 'Feldwebel',
    icon: 'military_tech',
    description: 'LINKS! RECHTS! VORWÄRTS!',
    pitch: 0.6,
    rate: 0.6,
    transform: _drillTransform,
  ),
  'racer': NavVoiceProfile(
    id: 'racer',
    name: 'Racer',
    icon: 'sports_motorsports',
    description: 'Tief, rau, Vollgas!',
    pitch: 0.5,
    rate: 0.52,
    transform: _racerNavTransform,
  ),
};

// ─── Voice Transforms ────────────────────────────────────────────────────────

String _piratTransform(String text) {
  return text
      .replaceAll('Links abbiegen', 'Nach Backbord drehen, Arrr')
      .replaceAll('links abbiegen', 'nach Backbord drehen, Arrr')
      .replaceAll('Rechts abbiegen', 'Nach Steuerbord drehen, Arrr')
      .replaceAll('rechts abbiegen', 'nach Steuerbord drehen, Arrr')
      .replaceAll('Leicht links', 'Leicht nach Backbord, Matrose')
      .replaceAll('leicht links', 'leicht nach Backbord, Matrose')
      .replaceAll('Leicht rechts', 'Leicht nach Steuerbord, Matrose')
      .replaceAll('leicht rechts', 'leicht nach Steuerbord, Matrose')
      .replaceAll('Scharf links', 'Hart Backbord! Festhalten!')
      .replaceAll('Scharf rechts', 'Hart Steuerbord! Festhalten!')
      .replaceAll('Wenden', 'Klar zum Wenden! Umkehren!')
      .replaceAll('Geradeaus', 'Kurs halten, geradeaus segeln')
      .replaceAll('Kreisverkehr', 'In den Strudel rein, Arrr')
      .replaceAll('Du hast dein Ziel erreicht. Viel Spaß noch!',
          'Land in Sicht! Wir haben den Schatz gefunden! Arrr!')
      .replaceAll('Route wird neu berechnet.',
          'Oje, die Seekarte stimmt nicht! Neuen Kurs berechnen!')
      .replaceAll('Navigation gestartet.', 'Leinen los! Wir stechen in See!')
      .replaceAll('In 500 Metern', 'In 500 Schritt')
      .replaceAll('In 200 Metern', 'In 200 Schritt');
}

String _bikerTransform(String text) {
  return text
      .replaceAll('Links abbiegen', 'Links rüber, Bruder')
      .replaceAll('links abbiegen', 'links rüber, Bruder')
      .replaceAll('Rechts abbiegen', 'Rechts rüber, Bruder')
      .replaceAll('rechts abbiegen', 'rechts rüber, Bruder')
      .replaceAll('Leicht links', 'Easy links, Bro')
      .replaceAll('leicht links', 'easy links, Bro')
      .replaceAll('Leicht rechts', 'Easy rechts, Bro')
      .replaceAll('leicht rechts', 'easy rechts, Bro')
      .replaceAll('Scharf links', 'Vollgas links reinlegen!')
      .replaceAll('Scharf rechts', 'Vollgas rechts reinlegen!')
      .replaceAll('Wenden', 'Umdrehen und zurück donnern!')
      .replaceAll('Geradeaus', 'Gerade durch, Gas geben!')
      .replaceAll('Kreisverkehr', 'Ab in den Kreisverkehr, easy')
      .replaceAll('Du hast dein Ziel erreicht. Viel Spaß noch!',
          'Yeah Bruder! Angekommen! Ride on!')
      .replaceAll('Route wird neu berechnet.',
          'Eh, falscher Weg. Neue Route, Bro!')
      .replaceAll('Navigation gestartet.', 'Los gehts, Bruder! Ride on!');
}

String _robotTransform(String text) {
  return text
      .replaceAll('Links abbiegen', 'Richtungsänderung, 90 Grad links, initiiert')
      .replaceAll('links abbiegen', 'Richtungsänderung, 90 Grad links, initiiert')
      .replaceAll('Rechts abbiegen', 'Richtungsänderung, 90 Grad rechts, initiiert')
      .replaceAll('rechts abbiegen', 'Richtungsänderung, 90 Grad rechts, initiiert')
      .replaceAll('Leicht links', 'Kurskorrektur, 30 Grad links')
      .replaceAll('Leicht rechts', 'Kurskorrektur, 30 Grad rechts')
      .replaceAll('Scharf links', 'Warnung. Scharfe Kurve links. 120 Grad.')
      .replaceAll('Scharf rechts', 'Warnung. Scharfe Kurve rechts. 120 Grad.')
      .replaceAll('Wenden', 'U-Turn. 180 Grad Drehung einleiten.')
      .replaceAll('Geradeaus', 'Kurs beibehalten. Geradeaus.')
      .replaceAll('Kreisverkehr', 'Kreisverkehr detektiert. Einfahrt.')
      .replaceAll('Du hast dein Ziel erreicht. Viel Spaß noch!',
          'Zielkoordinaten erreicht. Mission abgeschlossen. Beep boop.')
      .replaceAll('Route wird neu berechnet.',
          'Fehler. Neuberechnung läuft. Bitte warten.')
      .replaceAll('Navigation gestartet.', 'Navigation aktiviert. Systeme online.')
      .replaceAll('Jetzt', 'Jetzt. Ausführen.');
}

String _opaTransform(String text) {
  return text
      .replaceAll('Links abbiegen', 'Links abbiegen, mein Junge, schön langsam')
      .replaceAll('links abbiegen', 'links abbiegen, mein Junge, schön langsam')
      .replaceAll('Rechts abbiegen', 'Rechts abbiegen, ganz vorsichtig')
      .replaceAll('rechts abbiegen', 'rechts abbiegen, ganz vorsichtig')
      .replaceAll('Leicht links', 'Ein bisschen nach links, nicht so hastig')
      .replaceAll('Leicht rechts', 'Ein bisschen nach rechts, immer mit der Ruhe')
      .replaceAll('Scharf links', 'Achtung, scharf links! Nicht so schnell!')
      .replaceAll('Scharf rechts', 'Achtung, scharf rechts! Immer langsam!')
      .replaceAll('Wenden', 'Och, umdrehen? Na dann mal zurück')
      .replaceAll('Geradeaus', 'Einfach geradeaus, ist doch nicht schwer')
      .replaceAll('Kreisverkehr', 'In den Kreisverkehr, aber nicht schwindelig werden')
      .replaceAll('Du hast dein Ziel erreicht. Viel Spaß noch!',
          'So, da wären wir! Endlich angekommen, mein Junge!')
      .replaceAll('Route wird neu berechnet.',
          'Oje, verfahren! Zu meiner Zeit hatten wir noch Landkarten!')
      .replaceAll('Navigation gestartet.',
          'Na dann wollen wir mal, immer schön langsam!');
}

String _drillTransform(String text) {
  return text
      .replaceAll('Links abbiegen', 'LINKS ABBIEGEN! BEWEGEN!')
      .replaceAll('links abbiegen', 'LINKS ABBIEGEN! BEWEGEN!')
      .replaceAll('Rechts abbiegen', 'RECHTS ABBIEGEN! SOFORT!')
      .replaceAll('rechts abbiegen', 'RECHTS ABBIEGEN! SOFORT!')
      .replaceAll('Leicht links', 'LEICHT LINKS! ZACKIG!')
      .replaceAll('Leicht rechts', 'LEICHT RECHTS! TEMPO!')
      .replaceAll('Scharf links', 'SCHARF LINKS! ACHTUNG!')
      .replaceAll('Scharf rechts', 'SCHARF RECHTS! ACHTUNG!')
      .replaceAll('Wenden', 'KEHRT! UMDREHEN! VORWÄRTS MARSCH!')
      .replaceAll('Geradeaus', 'GERADEAUS! NICHT SCHLAFEN!')
      .replaceAll('Kreisverkehr', 'AB IN DEN KREISVERKEHR! LOS LOS!')
      .replaceAll('Du hast dein Ziel erreicht. Viel Spaß noch!',
          'ZIEL ERREICHT! MISSION ERFÜLLT! WEGTRETEN!')
      .replaceAll('Route wird neu berechnet.',
          'WIR HABEN UNS VERFAHREN! NEUER BEFEHL WIRD ERTEILT!')
      .replaceAll('Navigation gestartet.',
          'ACHTUNG! NAVIGATION GESTARTET! VORWÄRTS MARSCH!')
      .replaceAll('Jetzt', 'JETZT!')
      .replaceAll('In 500 Metern', 'IN 500 METERN')
      .replaceAll('In 200 Metern', 'IN 200 METERN');
}

String _racerNavTransform(String text) {
  return text
      .replaceAll('Links abbiegen', 'Links reinlegen, Alter')
      .replaceAll('links abbiegen', 'links reinlegen, Alter')
      .replaceAll('Rechts abbiegen', 'Rechts reinlegen, los')
      .replaceAll('rechts abbiegen', 'rechts reinlegen, los')
      .replaceAll('Leicht links', 'Leicht links, easy')
      .replaceAll('leicht links', 'leicht links, easy')
      .replaceAll('Leicht rechts', 'Leicht rechts, smooth')
      .replaceAll('leicht rechts', 'leicht rechts, smooth')
      .replaceAll('Scharf links', 'Harte Linke, festhalten!')
      .replaceAll('Scharf rechts', 'Harte Rechte, festhalten!')
      .replaceAll('Wenden', 'Dreh um und gib Gummi!')
      .replaceAll('Geradeaus', 'Geradeaus, Vollgas')
      .replaceAll('Kreisverkehr', 'Kreisverkehr, rein und durch')
      .replaceAll('Du hast dein Ziel erreicht. Viel Spaß noch!',
          'Ziel erreicht, Maschine aus. Gute Fahrt, Alter!')
      .replaceAll('Route wird neu berechnet.',
          'Falscher Weg, Kumpel. Neue Strecke kommt.')
      .replaceAll('Navigation gestartet.',
          'Strecke steht, Alter. Gib Gummi!')
      .replaceAll('Jetzt', 'Jetzt!')
      .replaceAll('In 500 Metern', 'In fünfhundert Metern')
      .replaceAll('In 200 Metern', 'In zweihundert Metern');
}
