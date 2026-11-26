# Änderungen

English version: [CHANGELOG.md](CHANGELOG.md)

## 0.2.0

Ergänzungen für Apps, die eigene Screens zeigen. Nichts Bestehendes ändert sich.

- `AusweisAppNfc` (umgesetzt von `MethodChannelAusweisAppNfc`) meldet den NFC-Zustand des Geräts als `NfcStatus` (`unsupported`, `disabled`, `available`), ohne laufendes SDK. `openSettings()` öffnet unter Android die NFC-Einstellungen des Systems; unter iOS, das keine hat, tut der Aufruf nichts und gibt `false` zurück.
- `FailureKind` ordnet Fehlercodes den Klassen `network`, `timeout`, `userCancelled`, `cardConnection` und `other` zu. Es gibt sie als `AuthResult.failureKind`, `ChangePinCompleted.failureKind`, `AusweisAppException.failureKind` und `FailureKind.fromReason`; die rohen Codes bleiben unverändert. Die Zuordnung folgt der Liste der Fehlercodes in der SDK-Dokumentation, die jetzt Teil des Repositorys ist (`AusweisApp-community/docs/failurecodes/failurecodes.rst`).
- `FakeAusweisAppNfc` in `package:flutter_ausweisapp/testing.dart` ersetzt den NFC-Zustand in Tests.
- Die Beispiel-App zeigt den NFC-Zustand, einen Knopf zu den NFC-Einstellungen und die Fehlerklasse in ihrem Protokoll.
- Dokumentiert: Das Android-Paket des SDK trägt NFC als optionale Fähigkeit ein; eine App mit dem Plugin bleibt also auf Geräten ohne NFC installierbar.

Die NFC-Funktionen sind nur auf einem iOS-Simulator gelaufen. Auf echten Geräten sind sie auf beiden Plattformen ungeprüft; siehe `docs/geraetetest.md`.

## 0.1.0

Erste Fassung. Das Plugin bindet das AusweisApp-SDK 2.6.3 für Android und iOS in Flutter ein und kann:

- das SDK starten und stoppen und alle 20 Kommandos des SDK als Methoden senden, darunter Authentisierung, PIN-Änderung (auch Transport-PIN), PIN, CAN und PUK, Zugriffsrechte ansehen und einschränken, Zertifikat, Status und Abbruch,
- alle Nachrichten des SDK als benannte Ereignisse in einem Stream liefern, unbekannte Nachrichten mit dem Roh-JSON,
- den NFC-Lesemodus unter Android selbst steuern,
- unter iOS den NFC-Dialog mit eigenen Texten zeigen und mit `interrupt()` schließen,
- die `tcTokenURL` aus einem eID-Client-Link lesen (`tcTokenUrlFromEidClientLink`),
- Kommandos und Nachrichten auf Wunsch mitschreiben, wobei PIN, CAN, PUK und Header-Werte durch `***` ersetzt werden,
- mit `FakeAusweisAppTransport` (`package:flutter_ausweisapp/testing.dart`) ohne Gerät getestet werden.

Das Plugin steht unter der EUPL 1.2.

Der Git-Tag `v0.0.1` bezeichnet denselben Code, bevor die Versionsnummer auf 0.1.0 gesetzt wurde.

Unter iOS ist das Plugin auf einem echten Gerät geprüft, unter Android ist echtes NFC noch ungetestet; siehe `docs/geraetetest.md`.
