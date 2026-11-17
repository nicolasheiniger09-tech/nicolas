# 💎 Kristall-Garten – ein Roblox-Simulator

Ein eigenes Spiel im beliebtesten Roblox-Genre (Sammel-/Wachstums-Simulator):

- Jeder Spieler bekommt einen **eigenen Garten** mit Erdfeldern.
- Man kauft **Kristall-Samen**, pflanzt sie, sie **wachsen** (auch wenn man offline ist!), man **erntet** und **verkauft** sie.
- 7 Kristallsorten: Quarz → Amethyst → Rubin → Saphir → Smaragd → Diamant → Sternenkristall
- Seltene Varianten: **Gold** (6 %, x3 Wert) und **Regenbogen** (1 %, x10 Wert, leuchtet bunt)
- **Upgrades**: mehr Felder, schnelleres Wachstum
- **Rebirth**: alles zurücksetzen, dafür dauerhaft +50 % Münzen und neue Kristalle
- **Tägliche Belohnung**, damit Spieler jeden Tag wiederkommen
- **Speichern** des Fortschritts (DataStore)
- **Robux-Shop**: 2 Game Passes + 3 Developer Products (damit verdienst du Robux)
- Funktioniert auf PC, Handy und Tablet

## 1. Spiel in Roblox Studio einfügen (ca. 5 Minuten)

1. **Roblox Studio** öffnen → **Neu** → Vorlage **„Baseplate“** wählen.
2. Links im **Explorer**: Rechtsklick auf **ServerScriptService** → **Objekt einfügen** → **Script**.
   Das Script `GameServer` nennen, alles darin löschen und den Inhalt von
   [`GameServer.server.lua`](GameServer.server.lua) hineinkopieren.
3. Im Explorer **StarterPlayer** aufklappen → Rechtsklick auf **StarterPlayerScripts** →
   **Objekt einfügen** → **LocalScript**. `Client` nennen und den Inhalt von
   [`Client.client.lua`](Client.client.lua) hineinkopieren.
4. Oben auf **▶ Testen (Play)** klicken. Du stehst in deinem Garten. Klicke auf ein Erdfeld zum Pflanzen!

> Damit das **Speichern** auch in Studio funktioniert: Spiel zuerst veröffentlichen (Schritt 2),
> dann **Datei → Spieleinstellungen → Sicherheit → „Studio-Zugriff auf API-Dienste aktivieren“** einschalten.

## 2. Veröffentlichen

1. In Studio: **Datei → Auf Roblox veröffentlichen**.
2. Einen Namen eingeben, z. B. **„💎 Kristall-Garten Simulator“**, und eine kurze Beschreibung.
3. **Spieleinstellungen → Allgemein**: Spiel auf **Öffentlich** stellen.
4. **Spieleinstellungen → Orte (Places) → Max. Spieler auf 10 stellen.**
   Wichtig: Es gibt genau 10 Gärten! (Mehr Gärten → `PLOT_COUNT` im Server-Skript ändern.)
5. Im **Creator Hub** (create.roblox.com) ein **Icon** und **Vorschaubilder** hochladen.
   Die sind das Wichtigste, damit Leute draufklicken.

## 3. Robux verdienen einrichten

Im Creator Hub → dein Spiel → **Monetarisierung**:

| Was | Wo erstellen | Vorschlag Preis | Im Skript eintragen bei |
|---|---|---|---|
| Doppelte Münzen | Game Passes | 99–199 Robux | `GAMEPASS_DOUBLE_COINS` |
| Turbo-Wachstum | Game Passes | 149–249 Robux | `GAMEPASS_FAST_GROW` |
| Münzpaket | Developer Products | 25–49 Robux | `PRODUCT_COINS_SMALL` |
| Riesen-Münzpaket | Developer Products | 99–149 Robux | `PRODUCT_COINS_BIG` |
| Sofort fertig | Developer Products | 15–29 Robux | `PRODUCT_INSTANT_GROW` |

Nach dem Erstellen bekommst du für jedes eine **ID-Nummer**. Diese oben im Server-Skript bei
`CONFIG` statt der `0` eintragen und das Spiel neu veröffentlichen. Die Münzpakete wachsen
automatisch mit dem Fortschritt des Spielers mit, damit sie immer etwas wert sind.

## 4. Ehrliche Tipps, damit Leute spielen

- **Icon und Thumbnail** sind am wichtigsten: bunte Kristalle, großer Text, ein „Wow“-Moment.
- **Regelmäßig Updates** machen (neue Kristalle, Events). Roblox zeigt aktive Spiele öfter an.
- **Freunde einladen**, die ersten Spieler kommen fast immer über Freunde und Videos.
- Mit Robux kann man im Creator Hub **Werbung** schalten. Fang klein an und schau, was passiert.
- **Realistisch bleiben:** Die meisten Roblox-Spiele verdienen wenig oder gar nichts. Es braucht
  Geduld und viele Verbesserungen. Robux in echtes Geld tauschen (**DevEx**) geht erst ab
  **30.000 verdienten Robux** und man muss mindestens **13 Jahre** alt sein und ein verifiziertes Konto haben.
  Wenn du jünger als 18 bist, frag deine Eltern, bevor du Werbung kaufst oder Geld auszahlen lässt.

## Werte anpassen

Alles Wichtige steht oben im Server-Skript: Preise, Wachstumszeiten und Werte der Kristalle (`CRYSTALS`),
die Chancen für Gold und Regenbogen (`MUTATIONS`), Startmünzen, Anzahl Felder usw.
