# flutter_ausweisapp

`flutter_ausweisapp` bindet das AusweisApp-SDK von Governikus (Version 2.6.3) in Flutter-Apps für Android und iOS ein. Damit kann sich eine Nutzerin oder ein Nutzer mit dem Online-Ausweis authentisieren, ohne die App zu verlassen: Das SDK liest die Karte per NFC, die App zeigt alle Dialoge (PIN, CAN, PUK, Zugriffsrechte) auf ihren eigenen Screens. Das Plugin bringt keine Oberfläche mit. Es reicht die JSON-Kommandos und -Nachrichten des SDK an Dart durch und stellt sie als typisierte Methoden und als Ereignis-Stream bereit.

Der Entwurf mit allen Entscheidungen steht in `docs/superpowers/specs/2026-11-24-flutter-ausweisapp-bridge-design.md`.

**Wichtig: Echtes NFC ist bisher ungetestet.** Emulator und Simulator haben kein NFC. Die Simulator-Karte des SDK umgeht das Lesen der Karte vollständig. Alles, was NFC berührt (Karte anlegen, Karte wegziehen, Hintergrund, NFC-Dialog unter iOS), gilt erst als geprüft, wenn die Prüfliste in `docs/geraetetest.md` auf echten Geräten durchlaufen wurde.

## Inhalt

- [Nutzung](#nutzung)
- [Einrichtung Android](#einrichtung-android)
- [Einrichtung iOS](#einrichtung-ios)
- [Plattformunterschiede](#plattformunterschiede)
- [Lebenszyklus und Fehler](#lebenszyklus-und-fehler)
- [Umgang mit PIN, CAN und PUK](#umgang-mit-pin-can-und-puk)
- [Simulator-Karte](#simulator-karte)
- [Entwicklung](#entwicklung)
- [SDK-Update](#sdk-update)
- [Abgrenzung: Keycloak und BundID](#abgrenzung-keycloak-und-bundid)
- [Lizenz](#lizenz)

## Nutzung

Das Plugin wird über einen Pfad- oder Git-Eintrag in der `pubspec.yaml` der App eingebunden (`publish_to: none`, es ist nicht auf pub.dev veröffentlicht). Danach genügt ein Import:

```dart
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
```

Die Klasse `AusweisApp` hat für jedes SDK-Kommando eine Methode. Antworten kommen ausschließlich als Ereignisse über den Stream `events`, benannt nach ihrer Bedeutung (zum Beispiel `PinRequested`).

**Abonnieren Sie `events`, bevor Sie `start()` aufrufen.** Der Stream ist ein Broadcast-Stream; Ereignisse ohne Zuhörer gehen verloren.

```dart
final eid = AusweisApp();

final subscription = eid.events.listen((event) {
  switch (event) {
    case AuthenticationStarted():
      showProgress();
    case AccessRightsRequested(:final rights):
      showRights(rights); // danach eid.accept() oder eid.cancel()
    case InsertCardRequested():
      showCardHint();
    case PinRequested(:final reader):
      showPinScreen(reader.card?.retryCounter); // danach eid.setPin(...)
    case CanRequested():
      showCanScreen(); // danach eid.setCan(...)
    case PukRequested():
      showPukScreen(); // danach eid.setPuk(...)
    case NewPinRequested():
      showNewPinScreen(); // danach eid.setNewPin(...)
    case Paused():
      showReposition(); // danach eid.continueWorkflow()
    case AuthenticationCompleted(:final result):
      if (result.isSuccess) finishLogin(result.url);
    case ChangePinCompleted(:final success):
      showPinChanged(success);
    default:
      break;
  }
});

await eid.start();
await eid.startAuthentication(tcTokenUrl: Uri.parse(tcTokenUrl));
```

Die `showXyz`-Funktionen sind Platzhalter für Ihre eigenen Screens. `tcTokenUrl` ist die Adresse, die der eID-Server der Gegenstelle liefert. Kommt sie als eID-Client-Link (`…/eID-Client?tcTokenURL=…`) aus einem Web-Ablauf, liest `tcTokenUrlFromEidClientLink(Uri)` sie heraus und gibt `null` zurück, wenn der Link nicht passt oder die Adresse nicht mit `https` beginnt.

Zum Aufräumen rufen Sie `await eid.stop()` und danach `eid.dispose()` auf. Weitere Möglichkeiten:

- `startChangePin()` startet eine PIN-Änderung (auch für die fünfstellige Transport-PIN).
- `setAccessRights(...)` schränkt die optionalen Zugriffsrechte ein, `getCertificate()` liefert das Zertifikat der Gegenstelle.
- `rawMessages` liefert jede Nachricht des SDK unverändert, `sendRaw(map)` sendet ein Kommando, das die typisierte API noch nicht kennt.
- `logger:` im Konstruktor schreibt Kommandos und Nachrichten mit, siehe unten.

### Die App ohne Gerät testen

`package:flutter_ausweisapp/testing.dart` enthält `FakeAusweisAppTransport`. Mit `AusweisApp(transport: fake)` lassen sich die eigenen Screens in Widget-Tests prüfen, ohne SDK und ohne Gerät.

## Einrichtung Android

1. **minSdk 28.** Das SDK braucht minSdk 28. Setzen Sie `minSdk = 28` (oder höher) in `android/app/build.gradle.kts` der App.
2. **Eigene `Application`-Klasse anpassen.** Das SDK läuft in einem eigenen Prozess, dessen Name auf `ausweisapp2_service` endet, und erzeugt dort die `Application`-Klasse der App ein zweites Mal. Hat Ihre App eine eigene `Application`-Klasse mit Initialisierungen (zum Beispiel Firebase), muss sie diese in diesem Prozess überspringen:

   ```kotlin
   class MyApp : Application() {
       override fun onCreate() {
           super.onCreate()
           if (Application.getProcessName().endsWith("ausweisapp2_service")) return
           // Einmalige Initialisierung der App, zum Beispiel Firebase.
       }
   }
   ```

   Ohne eigene `Application`-Klasse ist nichts zu tun.
3. **Geräte.** Das SDK unterstützt nur Android-Geräte mit Extended-Length-NFC. Auf anderen Geräten lässt sich der Ausweis nicht lesen.

Das Plugin bindet den SDK-Dienst selbst. Die Berechtigung `android.permission.NFC` und der Dienst kommen über das Android-Paket des SDK in die App. Den NFC-Lesemodus schaltet das Plugin selbst ein und aus, solange das SDK läuft und die Activity im Vordergrund ist; Ihre App braucht dafür keinen eigenen nativen Code.

## Einrichtung iOS

1. **Swift Package Manager einschalten.** Das Plugin unterstützt unter iOS nur Swift Package Manager (es gibt kein Podspec). Aktivieren Sie ihn in der `pubspec.yaml` der App, ohne die globale Flutter-Konfiguration zu ändern:

   ```yaml
   flutter:
     config:
       enable-swift-package-manager: true
   ```

   Plugins Ihrer App, die noch kein Swift Package anbieten, bindet Flutter weiterhin über CocoaPods ein. Die Umstellung muss nicht in einem Schritt erfolgen.
2. **Mindestversion iOS 17.0.** Setzen Sie das Deployment Target der App auf mindestens 17.0.
3. **NFC-Entitlement.** Die App braucht in ihrer `Runner.entitlements` den Eintrag `com.apple.developer.nfc.readersession.formats` mit dem Wert `TAG`. Dazu muss die Fähigkeit „Near Field Communication Tag Reading" am App-Identifier im Apple-Entwicklerkonto aktiv sein.
4. **Zwei Einträge in der `Info.plist`.**

   ```xml
   <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
   <array>
     <string>E80704007F00070302</string>
   </array>
   <key>NFCReaderUsageDescription</key>
   <string>Die App liest per NFC Ihren Personalausweis, um Sie online auszuweisen.</string>
   ```

   Der Text unter `NFCReaderUsageDescription` erscheint dem Nutzer; passen Sie ihn an Ihre App an.

Bekannte Einschränkung beim Bauen: Mit Flutter 3.41.7 und Xcode 27.2 schlägt `flutter build ios --simulator` für jede App fehl, auch für eine leere (beobachtet am 24.11.2026; Flutters Aufruf `lipo -verify_arch` wird abgelehnt). Builds für einen konkreten Simulator oder ein Gerät funktionieren, etwa `flutter run -d <id>`.

**Mehrere Flutter-Engines.** Das SDK existiert unter iOS einmal pro Prozess. Ruft eine zweite Engine `start()` auf, übernimmt sie die Nachrichten, und die erste Engine erfährt davon nichts. Nutzen Sie das Plugin aus einer einzigen Engine.

## Plattformunterschiede

| Funktion | Android | iOS |
| --- | --- | --- |
| `userInfoMessages` bei `startAuthentication` und `startChangePin` (Texte des NFC-Dialogs) | ohne Wirkung | wirkt |
| `interrupt()` (schließt den NFC-Dialog) | sendet nichts | wirkt |
| Ereignis `Disconnected` (Verbindung zum SDK verloren) | wird gemeldet | wird nicht gemeldet |
| NFC-Dialog | – | zeigt iOS selbst; seine Texte kommen über `userInfoMessages` |

Besonderheiten unter Android:

- Nach `stop()` beendet das SDK seinen eigenen Prozess. Ein `start()` direkt danach wartet bis zu 3 Sekunden, bis dieser Prozess beendet ist, und bindet erst dann neu. Sonst würde Android den Dienst erst nach einer Wartezeit von etwa 10 Sekunden neu starten.
- Bekannte Grenze: Wird das Plugin an eine Activity gehängt, die schon im Vordergrund ist (Add-to-App mit einem später eingefügten `FlutterFragment`), schaltet sich der NFC-Lesemodus erst nach dem nächsten Pausieren und Fortsetzen ein. Mit einer normalen `FlutterActivity` tritt das nicht auf.

## Lebenszyklus und Fehler

- `start()` hat eine Frist von standardmäßig 15 Sekunden und wirft `AusweisAppStartException` (Codes `start_failed`, `timeout`, `api_level`). Der erste Schritt von `start()` stellt das API-Level 3 ein.
- `stop()` wartet höchstens 15 Sekunden und wirft sonst `AusweisAppTransportException` (Code `timeout`).
- `dispose()` löst das Stoppen aus, wartet aber nicht darauf. Legen Sie direkt danach ein neues `AusweisApp` an, rufen Sie vorher `await stop()` auf.
- Kommandos bei nicht laufendem SDK werfen `AusweisAppNotRunningException`. Transportfehler beim Senden werfen `AusweisAppTransportException`.
- Fehlermeldungen des SDK (`BAD_STATE`, `INTERNAL_ERROR`, `INVALID`, `UNKNOWN_COMMAND`) kommen als Ereignisse an: `BadState`, `InternalError`, `InvalidCommand`, `UnknownCommand`. Nachrichten, die das Plugin nicht kennt, kommen als `UnknownMessageReceived` mit dem Roh-JSON.
- Ein fachlich gescheiterter Ablauf (falsche PIN, Abbruch, gesperrte Karte) ist **keine** Ausnahme, sondern ein normales Ereignis, etwa `AuthenticationCompleted` mit einem Ergebnis, dessen `isSuccess` false ist.

## Umgang mit PIN, CAN und PUK

- Das Plugin schreibt Kommandos mit Geheimnissen nie ins Log. Das Mitschreiben von Kommandos und Nachrichten ist standardmäßig aus (`logger:` im Konstruktor von `AusweisApp`). Wenn Sie es einschalten, ersetzt das Plugin PIN, CAN, PUK und die Werte von HTTP-Headern durch `***`.
- Unter Android überschreibt das Plugin das Zeichenfeld nach dem Senden mit Nullen.
- Bekannte Grenze: Die Eingabe wird in Flutter als Dart-String erfasst und lässt sich dort nicht gezielt aus dem Speicher löschen. Das gilt für jeden Flutter-Weg.

## Simulator-Karte

Das SDK bringt eine virtuelle Karte mit. Sie liegt in einem eingebauten Leser namens `Simulator` und wird mit `eid.setCard('Simulator')` eingelegt, zum Beispiel wenn `InsertCardRequested` kommt. Sie funktioniert nur gegen Testumgebungen, etwa den Governikus-Testdienst `https://test.governikus-eid.de/Autent-DemoApplication/api/eid/request`, und dafür braucht `startAuthentication` den Parameter `developerMode: true`.

Der Leser `Simulator` meldet sich als Leser mit eigener Tastatur. PIN, CAN, PUK und neue PIN müssen deshalb **ohne Wert** gesendet werden: `eid.setPin(null)`. Mit einem Wert lehnt das SDK die Eingabe jedes Mal ab.

Die Simulator-Karte läuft auch im Emulator und im Simulator, braucht aber Netzzugriff auf den Testdienst.

## Entwicklung

Tests in diesem Repository:

- `flutter test` im Wurzelverzeichnis führt die Unit-Tests aus, ohne Gerät.
- `flutter test` im Verzeichnis `example/` führt die Widget-Tests der Beispiel-App aus.
- `flutter test integration_test -d <Gerät>` im Verzeichnis `example/` führt die Integrationstests auf einem Emulator, Simulator oder Gerät aus. Der Test mit der Simulator-Karte braucht Netzzugriff auf den Governikus-Testdienst.

Die Beispiel-App in `example/` ist eine einfache Testoberfläche, die alle Abläufe anstößt. Wie Sie sie auf einem Gerät starten, steht in `example/README.md`; die Prüfliste für echte Geräte steht in `docs/geraetetest.md`.

**Hot Restart.** Nach einem Hot Restart läuft das native SDK weiter. `start()` kehrt dann sofort zurück. Ein laufender Ablauf bleibt bestehen und lässt sich mit `cancel()` beenden.

## SDK-Update

Die SDK-Version steht an zwei Stellen: in `android/build.gradle.kts` (`com.governikus:ausweisapp:2.6.3`) und in `ios/flutter_ausweisapp/Package.swift` (`exact: "2.6.3"`). Lesen Sie vor dem Anheben das SDK-Changelog unter `AusweisApp-community/docs/sdk/changelog.rst`, weil das Plugin das Protokoll selbst umsetzt und Änderungen dort nachzieht. Das Plugin stellt beim Start das API-Level 3 ein, damit ein neueres SDK das Verhalten nicht stillschweigend ändert.

## Abgrenzung: Keycloak und BundID

Dieses Plugin kümmert sich nur um den Kartenzugriff und nimmt eine `tcTokenURL` entgegen. Wie die App diese Adresse aus dem Keycloak- und BundID-Ablauf gewinnt und den Login danach abschließt, gehört zur App; ob BundID diesen Weg zulässt, ist nicht geprüft und muss mit den Verantwortlichen geklärt werden. Bis dahin lässt sich das Plugin vollständig gegen den Governikus-Testdienst entwickeln.

## Lizenz

Das AusweisApp-SDK steht unter der EUPL 1.2. Wer eine App mit diesem Plugin ausliefert, verbreitet das SDK mit. Was dabei zu beachten ist, steht in `NOTICE.md`. Die Datei `LICENSE` ist bis zur Klärung ein Platzhalter.
