# Änderungen

## 0.0.1

Erste Fassung. Das Plugin bindet das AusweisApp-SDK 2.6.3 für Android und iOS in Flutter ein und kann:

- das SDK starten und stoppen und alle 20 Kommandos des SDK als Methoden senden, darunter Authentisierung, PIN-Änderung (auch Transport-PIN), PIN, CAN und PUK, Zugriffsrechte ansehen und einschränken, Zertifikat, Status und Abbruch,
- alle Nachrichten des SDK als benannte Ereignisse in einem Stream liefern, unbekannte Nachrichten mit dem Roh-JSON,
- den NFC-Lesemodus unter Android selbst steuern,
- unter iOS den NFC-Dialog mit eigenen Texten zeigen und mit `interrupt()` schließen,
- die `tcTokenURL` aus einem eID-Client-Link lesen (`tcTokenUrlFromEidClientLink`),
- Kommandos und Nachrichten auf Wunsch mitschreiben, wobei PIN, CAN, PUK und Header-Werte durch `***` ersetzt werden,
- mit `FakeAusweisAppTransport` (`package:flutter_ausweisapp/testing.dart`) ohne Gerät getestet werden.

Das Plugin steht unter der EUPL 1.2.

Echtes NFC ist noch nicht auf Geräten geprüft; siehe `docs/geraetetest.md`.
