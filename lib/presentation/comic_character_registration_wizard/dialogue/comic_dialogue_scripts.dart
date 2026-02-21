// lib/presentation/comic_character_registration_wizard/dialogue/comic_dialogue_scripts.dart

/// Central place for all comic dialogue bubble texts.
///
/// IMPORTANT: The step numbers must match the order in
/// `ComicCharacterRegistrationWizard`.
class ComicDialogueScripts {
  static String textForStep({
    required int step,
    required Map<String, dynamic> form,
  }) {
    final nameRaw = (form["name"] ?? "").toString().trim();
    final name = nameRaw.isEmpty ? "Biker" : nameRaw;

    switch (step) {
      case 0:
        return "Willkommen bei Bikergram!\nBereit für dein Profil?";

      case 1:
        return "Nice! Welche Sprache passt zu dir?\nTippe einfach auf eine Flagge.";

      case 2:
        return "Hi $name! 😄\nWie darf ich dich nennen?";

      case 3:
        return "Alles klar, $name.\nWie alt bist du? (8–110)";

      case 4:
        return "Cool! Wo bist du zuhause?\nDeine PLZ reicht völlig.";

      case 5:
        return "Fast fertig.\nWelche E‑Mail sollen wir nutzen?";

      case 6:
        return "Jetzt wird’s spannend!\nWie viele Jahre fährst du schon?";

      case 7:
        return "Track‑Vibes? 😈\nHattest du schon Rennstrecke/Training?";

      case 8:
        return "Garage‑Time!\nWie viele Bikes hast du aktuell?";

      case 9:
        return "Schrauber‑Skills? 🔧\nWähle aus, was du selbst machst.";

      case 10:
        return "Und jetzt dein Style!\nLade ein Profilbild hoch (oder später).";

      case 11:
        return "Letzter Schritt: Passwort.\nMindestens 8 Zeichen – du schaffst das.";

      case 12:
        return "Kurz die Lizenz – und dann bist du drin.\nLet’s ride! 🏍️";

      default:
        return "Weiter geht’s…";
    }
  }
}
