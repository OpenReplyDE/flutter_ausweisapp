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

Die Beispiel-App zeigt ganz unten im Abschnitt „Protokoll" eine Liste. Jede Zeile `Ereignis: <Name>` ist ein Ereignis des Plugins, jede Zeile `Gesendet: <Befehl>` ein gesendeter Befehl, neueste Zeile oben. Hinter dem Namen eines Ereignisses stehen in Klammern seine wichtigsten Felder, zum Beispiel `PinRequested (Leser: …, Karte: ja, retryCounter: 3)`. Adressen zeigt das Protokoll nicht, weil sie ein Sitzungs-Token enthalten können; es zeigt nur, ob eine vorhanden ist (`URL: vorhanden`). Die Spalte „Erwartetes Ereignis" nennt die Namen, die dort erscheinen sollen. Tragen Sie in die Spalte „Ergebnis" ein, ob es so war (zum Beispiel ein Häkchen), und bei Abweichungen, was stattdessen erschien.

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
| Falsche PIN: bei `PinRequested` eine falsche PIN eintragen, „als PIN senden". | `PinRequested` erneut, der Wert `retryCounter` der Karte sinkt von 3 auf 2. Er steht im Protokoll in der Zeile des Ereignisses, etwa `PinRequested (…, retryCounter: 2, …)`. | |
| CAN-Fall: danach noch einmal eine falsche PIN senden. | `CanRequested`. Mit der richtigen CAN („als CAN senden") weiter mit `PinRequested`. | |
| PUK-Fall: nach dem CAN-Fall weiter falsche PINs senden, bis der Zähler auf 0 steht. | `PukRequested`. Mit der richtigen PUK („als PUK senden") weiter mit `PinRequested`. | |
| Abbruch: mitten im Ablauf (zum Beispiel bei `PinRequested`) „Abbrechen" antippen. | In der Regel `AuthenticationCompleted` mit gescheitertem Ergebnis; kein `Fehler:` im Protokoll. | |
| App in den Hintergrund und zurück: bei `InsertCardRequested` die App mit der Home-Taste verlassen, wieder öffnen, dann den Ausweis auflegen. | Nach der Rückkehr liest das Gerät den Ausweis: `PinRequested`. | |
| Bildschirm drehen während des Ablaufs: bei `PinRequested` das Gerät drehen. | Die Protokollliste bleibt erhalten, der Ablauf läuft weiter; PIN senden führt zu `AuthenticationCompleted`. | |
| NFC ausgeschaltet: in den Systemeinstellungen NFC ausschalten, „Anmeldung starten" bis `InsertCardRequested`, Ausweis auflegen. Dann NFC einschalten. | Offen, welches Ereignis das SDK ohne NFC meldet. Notieren Sie es. Nach dem Einschalten soll der Ausweis lesbar sein (`PinRequested`). | |
| PIN-Änderung: „PIN-Änderung starten" antippen, Ausweis auflegen, aktuelle PIN senden, dann „als neue PIN senden" mit einer neuen sechsstelligen PIN. | `ChangePinStarted`, `InsertCardRequested`, `PinRequested`, `NewPinRequested`, `ChangePinCompleted`. | |
| Transport-PIN (fünfstellig): „PIN-Änderung starten", Ausweis mit Transport-PIN auflegen, die fünfstellige Transport-PIN als PIN senden, dann eine neue sechsstellige PIN senden. | Wie bei der PIN-Änderung, am Ende `ChangePinCompleted`. | |

Die Zeilen zum iOS-NFC-Dialog und zu `interrupt()` gibt es nur unter iOS: Unter Android sendet das Plugin dafür nichts, und die Beispiel-App zeigt den Schalter zum automatischen Schließen des NFC-Dialogs dort nicht an.

## iOS

Unter iOS zeigt das System beim Lesen der Karte einen eigenen NFC-Dialog. Laut SDK-Dokumentation schließt das SDK diesen Dialog nicht, wenn es nach PIN, CAN, PUK oder neuer PIN fragt; die App schließt ihn mit dem Befehl `INTERRUPT` (Schaltfläche „Unterbrechen"). Ob sich die App bedienen lässt, solange der Dialog offen ist, ist auf einem Gerät noch nicht geprüft. Die ersten drei Zeilen klären das.

Im Abschnitt „PIN, CAN, PUK" der Beispiel-App steht der Schalter „NFC-Dialog bei PIN-, CAN- und PUK-Abfrage automatisch schließen". Er ist voreingestellt an: Dann sendet die App bei `PinRequested`, `CanRequested`, `PukRequested` und `NewPinRequested` selbst `INTERRUPT`, und im Protokoll erscheint `Gesendet: INTERRUPT (automatisch)`. Lassen Sie den Schalter an, wenn eine Zeile nichts anderes sagt. Erscheint der NFC-Dialog nach dem Senden von PIN, CAN oder PUK erneut, halten Sie den Ausweis wieder an das iPhone.

`INTERRUPT` ist nur direkt nach einem dieser vier Ereignisse erlaubt. Tippen Sie „Unterbrechen" zu einem anderen Zeitpunkt an, etwa vor dem Auflegen des Ausweises, antwortet das SDK mit `BadState`. Das ist das dokumentierte Verhalten des SDK und kein Fehler des Plugins.

| Schritt | Erwartetes Ereignis | Ergebnis |
| --- | --- | --- |
| Bedienbarkeit bei offenem NFC-Dialog (zuerst ausführen): den Schalter „NFC-Dialog … automatisch schließen" ausschalten, „Anmeldung starten", beim NFC-Dialog das iPhone an den Ausweis halten, bis `PinRequested` im Protokoll steht. Dann bei weiter geöffnetem NFC-Dialog versuchen, in das Feld „Eingabe" zu tippen. | Noch offen, bitte notieren: Bleibt der NFC-Dialog nach `PinRequested` offen? Lässt sich die App darunter bedienen? Nach der SDK-Dokumentation bleibt der Dialog offen, und die App ist darunter vermutlich nicht bedienbar. Kommen Sie nicht weiter, schließen Sie den Dialog über seine eigene Schaltfläche und notieren Sie, welches Ereignis dann folgt. | |
| `interrupt()` schließt den iOS-Dialog: im selben Zustand wie in der Zeile davor (Schalter aus, `PinRequested`, NFC-Dialog offen) „Unterbrechen" antippen. Lässt sich die App bei offenem Dialog nicht bedienen, entfällt diese Zeile; die nächste prüft dasselbe ohne Antippen. Danach den Schalter wieder einschalten. | Der NFC-Dialog schließt sich; im Protokoll `Gesendet: INTERRUPT`, kein `BadState`. | |
| Automatisches Schließen: Schalter an, „Anmeldung starten", Ausweis an das iPhone halten. | Nach `PinRequested` folgt `Gesendet: INTERRUPT (automatisch)`, der NFC-Dialog schließt sich, kein `BadState`. Danach lässt sich die PIN im Feld „Eingabe" eintragen. | |
| Karte anlegen: „Anmeldung starten", beim iOS-NFC-Dialog das iPhone an den Ausweis halten. | `InsertCardRequested`, nach dem Auflegen `PinRequested`; dazwischen meldet das SDK in der Regel `ReaderChanged`. | |
| Karte wegziehen und wieder anlegen: den Schalter ausschalten, damit der NFC-Dialog offen bleibt. Bei `PinRequested` den Ausweis kurz abnehmen und wieder auflegen; kommt `Paused`, „Fortsetzen" antippen. Danach den Schalter wieder einschalten. | `Paused`, nach „Fortsetzen" weiter mit `PinRequested`. Lässt sich „Fortsetzen" bei offenem Dialog nicht antippen, notieren Sie das. | |
| Falsche PIN: bei `PinRequested` eine falsche PIN eintragen, „als PIN senden". | `PinRequested` erneut, `retryCounter` sinkt von 3 auf 2. Der Wert steht im Protokoll in der Zeile des Ereignisses. | |
| CAN-Fall: danach noch einmal eine falsche PIN senden. | `CanRequested`. Mit der richtigen CAN weiter mit `PinRequested`. | |
| PUK-Fall: nach dem CAN-Fall weiter falsche PINs senden, bis der Zähler auf 0 steht. | `PukRequested`. Mit der richtigen PUK weiter mit `PinRequested`. | |
| Abbruch: mitten im Ablauf „Abbrechen" antippen. | In der Regel `AuthenticationCompleted` mit gescheitertem Ergebnis; kein `Fehler:` im Protokoll. | |
| App in den Hintergrund und zurück: bei `InsertCardRequested` mit der Home-Geste die App verlassen, wieder öffnen, dann den Ausweis auflegen. | Nach der Rückkehr liest das iPhone den Ausweis: `PinRequested`. Notieren Sie, ob der NFC-Dialog erneut erscheint. | |
| PIN-Änderung: „PIN-Änderung starten", Ausweis auflegen, aktuelle PIN senden, „als neue PIN senden" mit neuer sechsstelliger PIN. | `ChangePinStarted`, `InsertCardRequested`, `PinRequested`, `NewPinRequested`, `ChangePinCompleted`. | |
| Transport-PIN (fünfstellig): wie bei Android. | Wie bei der PIN-Änderung, am Ende `ChangePinCompleted`. | |
| NFC-Dialog mit eigenen Texten: „Authentisierung starten" und auf den NFC-Dialog des iPhones achten. | Der Dialog zeigt „Bitte halten Sie den Ausweis an das Gerät.", nach dem Auflegen „Ausweis wird gelesen. Nicht bewegen." und am Ende „Der Ausweis wurde gelesen." (die Texte der Beispiel-App). | |

Die Zeilen „NFC ausgeschaltet“ und „Bildschirm drehen“ gibt es nur für Android: Ein iPhone hat keinen NFC-Schalter in den Systemeinstellungen, und das Drehen gehört nach der Vorgabe nur zum Android-Test.
