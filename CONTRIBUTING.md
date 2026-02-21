# Contributing Guide (Bikergram / Motorinu)

Dieses Projekt wird parallel mit mehreren Assistenten (z. B. Claude + Codex) entwickelt.
Damit ihr euch **nicht gegenseitig blockiert**, gelten diese Regeln.

## 1) Branch-Strategie

- `main`: stabil, releasbar, keine direkten Commits.
- Pro Aufgabe ein eigener Branch:
  - `feat/<ticket>-<kurzname>`
  - `fix/<ticket>-<kurzname>`
  - optional mit Owner-Präfix: `claude/...`, `codex/...`
- Niemals zu zweit auf derselben Feature-Branch arbeiten.

## 2) Task Ownership

- Jede Aufgabe hat genau **einen Owner**.
- Cross-Cutting Tasks werden in kleinere Teilaufgaben gesplittet:
  - UI vs. API
  - Refactor vs. Feature
  - Android vs. Flutter

## 3) PR-Workflow

- Pro Aufgabe genau eine PR gegen `main` (oder definierte Integrations-Branch).
- PRs klein halten (idealerweise < 400 geänderte Zeilen).
- Draft PR früh öffnen, wenn größere Umbauten geplant sind.
- Vor Merge mindestens ein Review.

### PR-Template (Kurzform)

1. **Was wurde geändert?**
2. **Warum?**
3. **Wie getestet?**
4. **Risiken / Migration / Rollback**

## 4) Merge & Konflikt-Regeln

- Vor Start:
  - `git fetch origin`
  - Branch von aktuellem `origin/main` erstellen.
- Vor Push:
  - `git rebase origin/main` (oder Team-Standard: merge).
- Konflikte immer lokal lösen und erneut testen.
- Bei größeren Konflikten: zuerst mit kleinem "alignment commit" trennen (z. B. reine Formatierung separat).

## 5) Dateibereiche reservieren

Wenn ihr parallel arbeitet, reserviert im Issue/PR-Kommentar betroffene Bereiche, z. B.:

- `lib/presentation/messages/*` → Claude
- `lib/core/backend/*` → Codex

So vermeidet ihr Doppelarbeit und harte Merge-Konflikte.

## 6) Commit-Konvention

Conventional Commits:

- `feat: ...`
- `fix: ...`
- `refactor: ...`
- `chore: ...`
- `docs: ...`
- `test: ...`

Beispiel:

- `feat(messages): add unread badge on chat list`

## 7) Definition of Done (pro PR)

- Code kompiliert lokal.
- Betroffene Tests/Lints laufen.
- PR-Beschreibung vollständig.
- Kein Secret/Key im Diff.
- Relevante Screenshots bei UI-Änderungen.

## 8) Empfohlener Ablauf für "Claude + Codex"

1. Issue erstellen und Owner festlegen.
2. Je Assistent eigene Branch.
3. Beide liefern kleine PRs.
4. Erst technische Grundlage mergen (z. B. API), dann UI darauf.
5. Nach jedem Merge: der andere Assistent rebased auf `main`.

## 9) Schneller Start (Copy/Paste)

```bash
git fetch origin
git checkout main
git pull --ff-only
git checkout -b feat/<ticket>-<name>
```

Vor Push:

```bash
git fetch origin
git rebase origin/main
```

## 10) Kommunikationsregel

Bei Änderungen an zentralen Dateien (Routing, Theme, Auth-Flows, Build-Konfig):

- kurz ankündigen (Issue/PR-Kommentar),
- Draft PR verlinken,
- nach Merge andere Branches sofort rebasen.

Das hält die Zusammenarbeit mit mehreren Assistenten zuverlässig konfliktarm.
