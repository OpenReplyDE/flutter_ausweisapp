# Gerätetest: Prüfliste für Android und iOS

Diese Liste führen Sie auf echten Geräten mit der Beispiel-App aus `example/` durch. Sie ist nötig, weil Emulator und Simulator kein NFC haben: **Alles, was NFC berührt, ist bisher nicht auf echter Hardware geprüft und gilt erst als geprüft, wenn diese Liste durchlaufen ist.** Die Simulator-Karte des SDK umgeht das Lesen der Karte und taugt dafür nicht.

## Voraussetzungen

- Apple-Entwicklerteam mit NFC-Berechtigung (die Fähigkeit „Near Field Communication Tag Reading" am App-Identifier), ein NFC-fähiges iPhone mit iOS 17.0 oder neuer.
- Ein Android-Gerät mit Extended-Length-NFC, Android 9 (API 28) oder neuer.
- Ein Personalausweis (oder eine Testkarte) mit bekannter PIN, CAN und PUK. Für den Test „PIN-Änderung mit Transport-PIN" brauchen Sie eine Karte mit fünfstelliger Transport-PIN.
- Netzzugriff auf den Governikus-Testdienst.
- Die Beispiel-App läuft auf dem Gerät; siehe `example/README.md`.

**Achtung:** Die Zeilen „falsche PIN", „CAN-Fall" und „PUK-Fall" zählen die Fehlversuche der Karte herunter. Nach zwei falschen PINs verlangt die Karte die CAN, nach einer weiteren falschen PIN die PUK. Nutzen Sie dafür bevorzugt eine Testkarte. Eine erfolgreiche PIN-Eingabe setzt den Zähler in der Regel wieder zurück; prüfen Sie das nach dem Test.

## So lesen Sie die Tabellen

Die Beispiel-App zeigt ganz unten im Abschnitt „Protokoll" eine Liste. Jede Zeile `Ereignis: <Name>` ist ein Ereignis des Plugins, jede Zeile `Gesendet: <Befehl>` ein gesendeter Befehl, neueste Zeile oben. Die Spalte „Erwartetes Ereignis" nennt die Namen, die dort erscheinen sollen. Tragen Sie in die Spalte „Ergebnis" ein, ob es so war (zum Beispiel ein Häkchen), und bei Abweichungen, was stattdessen erschien.

Grundablauf, der in mehreren Zeilen vorkommt (im Folgenden „Anmeldung starten"):

1. „SDK starten" antippen.
2. Im Abschnitt „Authentisierung" die voreingestellte `tcTokenURL` und den eingeschalteten „Entwicklermodus" lassen und „Authentisierung starten" antippen. Erwartet: `AuthenticationStarted`, dann `AccessRightsRequested`.
3. „Akzeptieren" antippen. Erwartet: `InsertCardRequested`.
4. Den Ausweis an die NFC-Antenne des Geräts halten.

PIN, CAN und PUK tragen Sie im Feld „Eingabe" ein und senden sie mit „als PIN senden", „als CAN senden", „als PUK senden" oder „als neue PIN senden". Lassen Sie das Feld bei echten Karten nicht leer.

Eintrag je Plattform:

| | Android | iOS |
| --- | --- | --- |
| Gerätemodell | | |
| Betriebssystem-Version | | |
| Datum | | |
| Prüferin oder Prüfer | | |

## Android

| Schritt | Erwartetes Ereignis | Ergebnis |
| --- | --- | --- |
| Karte anlegen: „Anmeldung starten", Ausweis auflegen und liegen lassen. | `PinRequested`; vorher meldet das SDK in der Regel `ReaderChanged`. | |
| Karte wegziehen und wieder anlegen: bei `PinRequested` den Ausweis kurz abnehmen und wieder auflegen; kommt `Paused`, „Fortsetzen" antippen. | `Paused`, nach „Fortsetzen" weiter mit `PinRequested`. | |
| Falsche PIN: bei `PinRequested` eine falsche PIN eintragen, „als PIN senden". | `PinRequested` erneut, der Wert `retryCounter` der Karte sinkt von 3 auf 2. In der App nicht sichtbar: im Abschnitt „PIN, CAN, PUK" steht kein Zähler. Schalten Sie „Plugin-Protokoll mitschreiben" ein und lesen Sie `retryCounter` in der Zeile `[Plugin] <- …`. | |
| CAN-Fall: danach noch einmal eine falsche PIN senden. | `CanRequested`. Mit der richtigen CAN („als CAN senden") weiter mit `PinRequested`. | |
| PUK-Fall: nach dem CAN-Fall weiter falsche PINs senden, bis der Zähler auf 0 steht. | `PukRequested`. Mit der richtigen PUK („als PUK senden") weiter mit `PinRequested`. | |
| Abbruch: mitten im Ablauf (zum Beispiel bei `PinRequested`) „Abbrechen" antippen. | In der Regel `AuthenticationCompleted` mit gescheitertem Ergebnis; kein `Fehler:` im Protokoll. | |
| App in den Hintergrund und zurück: bei `InsertCardRequested` die App mit der Home-Taste verlassen, wieder öffnen, dann den Ausweis auflegen. | Nach der Rückkehr liest das Gerät den Ausweis: `PinRequested`. | |
| Bildschirm drehen während des Ablaufs: bei `PinRequested` das Gerät drehen. | Die Protokollliste bleibt erhalten, der Ablauf läuft weiter; PIN senden führt zu `AuthenticationCompleted`. | |
| NFC ausgeschaltet: in den Systemeinstellungen NFC ausschalten, „Anmeldung starten" bis `InsertCardRequested`, Ausweis auflegen. Dann NFC einschalten. | Offen, welches Ereignis das SDK ohne NFC meldet. Notieren Sie es. Nach dem Einschalten soll der Ausweis lesbar sein (`PinRequested`). | |
| PIN-Änderung: „PIN-Änderung starten" antippen, Ausweis auflegen, aktuelle PIN senden, dann „als neue PIN senden" mit einer neuen sechsstelligen PIN. | `ChangePinStarted`, `InsertCardRequested`, `PinRequested`, `NewPinRequested`, `ChangePinCompleted`. | |
| Transport-PIN (fünfstellig): „PIN-Änderung starten", Ausweis mit Transport-PIN auflegen, die fünfstellige Transport-PIN als PIN senden, dann eine neue sechsstellige PIN senden. | Wie bei der PIN-Änderung, am Ende `ChangePinCompleted`. | |

Die Zeilen zum iOS-NFC-Dialog und zu `interrupt()` gibt es nur unter iOS: Unter Android sendet das Plugin dafür nichts.

## iOS

| Schritt | Erwartetes Ereignis | Ergebnis |
| --- | --- | --- |
| Karte anlegen: „Anmeldung starten", beim iOS-NFC-Dialog das iPhone an den Ausweis halten. | `InsertCardRequested`, nach dem Auflegen `PinRequested`; dazwischen meldet das SDK in der Regel `ReaderChanged`. | |
| Karte wegziehen und wieder anlegen: bei `PinRequested` und geöffnetem NFC-Dialog den Ausweis kurz abnehmen und wieder auflegen; kommt `Paused`, „Fortsetzen" antippen. | `Paused`, nach „Fortsetzen" weiter mit `PinRequested`. | |
| Falsche PIN: bei `PinRequested` eine falsche PIN eintragen, „als PIN senden". | `PinRequested` erneut, `retryCounter` sinkt von 3 auf 2. Sichtbar im Protokoll bei eingeschaltetem „Plugin-Protokoll mitschreiben", Zeile `[Plugin] <- …`. | |
| CAN-Fall: danach noch einmal eine falsche PIN senden. | `CanRequested`. Mit der richtigen CAN weiter mit `PinRequested`. | |
| PUK-Fall: nach dem CAN-Fall weiter falsche PINs senden, bis der Zähler auf 0 steht. | `PukRequested`. Mit der richtigen PUK weiter mit `PinRequested`. | |
| Abbruch: mitten im Ablauf „Abbrechen" antippen. | In der Regel `AuthenticationCompleted` mit gescheitertem Ergebnis; kein `Fehler:` im Protokoll. | |
| App in den Hintergrund und zurück: bei `InsertCardRequested` mit der Home-Geste die App verlassen, wieder öffnen, dann den Ausweis auflegen. | Nach der Rückkehr liest das iPhone den Ausweis: `PinRequested`. Notieren Sie, ob der NFC-Dialog erneut erscheint. | |
| PIN-Änderung: „PIN-Änderung starten", Ausweis auflegen, aktuelle PIN senden, „als neue PIN senden" mit neuer sechsstelliger PIN. | `ChangePinStarted`, `InsertCardRequested`, `PinRequested`, `NewPinRequested`, `ChangePinCompleted`. | |
| Transport-PIN (fünfstellig): wie bei Android. | Wie bei der PIN-Änderung, am Ende `ChangePinCompleted`. | |
| NFC-Dialog mit eigenen Texten: „Authentisierung starten" und auf den NFC-Dialog des iPhones achten. | Der Dialog zeigt „Bitte halten Sie den Ausweis an das Gerät.", nach dem Auflegen „Ausweis wird gelesen. Nicht bewegen." und am Ende „Der Ausweis wurde gelesen." (die Texte der Beispiel-App). | |
| `interrupt()` schließt den iOS-Dialog: bei geöffnetem NFC-Dialog (vor dem Auflegen des Ausweises) „Unterbrechen" antippen. | Der NFC-Dialog schließt sich; im Protokoll `Gesendet: INTERRUPT`. | |

Die Zeilen „NFC ausgeschaltet“ und „Bildschirm drehen“ gibt es nur für Android: Ein iPhone hat keinen NFC-Schalter in den Systemeinstellungen, und das Drehen gehört nach der Vorgabe nur zum Android-Test.
