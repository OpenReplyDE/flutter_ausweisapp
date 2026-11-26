# flutter_ausweisapp

English version: [README.md](README.md)

`flutter_ausweisapp` bindet das AusweisApp-SDK von Governikus (Version 2.6.3) in Flutter-Apps für Android und iOS ein. Damit kann sich eine Nutzerin oder ein Nutzer mit dem Online-Ausweis authentisieren, ohne die App zu verlassen: Das SDK liest die Karte per NFC, die App zeigt alle Dialoge (PIN, CAN, PUK, Zugriffsrechte) auf ihren eigenen Screens. Das Plugin bringt keine Oberfläche mit. Es reicht die JSON-Kommandos und -Nachrichten des SDK an Dart durch und stellt sie als typisierte Methoden und als Ereignis-Stream bereit.

**Stand der Gerätetests.** Unter iOS ist das Plugin auf einem iPhone 16 Pro mit iOS 27.2.1 und einem echten Personalausweis geprüft, einschließlich einer vollständigen Anmeldung gegen einen Produktivdienst; die Ergebnisse stehen in `docs/geraetetest.md`. **Unter Android ist echtes NFC noch ungetestet:** Emulator und Simulator haben kein NFC, und die Simulator-Karte des SDK umgeht das Lesen der Karte vollständig. Alles, was unter Android NFC berührt, gilt erst als geprüft, wenn die Prüfliste dort auf einem echten Gerät durchlaufen wurde. Die mit Version 0.2.0 ergänzten Funktionen (NFC-Status und NFC-Einstellungen) sind auf demselben iPhone bestätigt; unter Android sind sie noch auf keinem Gerät gelaufen.

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
- [Abgrenzung: Login-Ablauf der App](#abgrenzung-login-ablauf-der-app)
- [Lizenz](#lizenz)

## Nutzung

Das Plugin wird über einen Git-Eintrag in der `pubspec.yaml` der App eingebunden (es ist nicht auf pub.dev veröffentlicht; den Eintrag zeigt [docs/integration.de.md](docs/integration.de.md)). Danach genügt ein Import:

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
    case AuthenticationStartFailed(:final error):
      showStartError(error); // RUN_AUTH abgelehnt, etwa wegen der tcTokenURL
    case AccessRightsRequested(:final rights):
      showRights(rights); // danach eid.accept() oder eid.cancel()
    case InsertCardRequested():
      showCardHint();
    case PinRequested(:final reader):
      eid.interrupt(); // schließt unter iOS den NFC-Dialog, siehe unten
      showPinScreen(reader.card?.retryCounter); // danach eid.setPin(...)
    case CanRequested():
      eid.interrupt();
      showCanScreen(); // danach eid.setCan(...)
    case PukRequested():
      eid.interrupt();
      showPukScreen(); // danach eid.setPuk(...)
    case NewPinRequested():
      eid.interrupt();
      showNewPinScreen(); // danach eid.setNewPin(...)
    case Paused():
      showReposition(); // danach eid.continueWorkflow()
    case AuthenticationCompleted(:final result):
      // Die URL meldet das Ergebnis an den Dienst, auch einen Fehler.
      if (result.url case final url?) openResultUrl(url);
      showResult(result.isSuccess);
    case ChangePinCompleted(:final success):
      showPinChanged(success);
    default:
      break;
  }
});

await eid.start();
await eid.startAuthentication(tcTokenUrl: Uri.parse(tcTokenUrl));
```

Die `showXyz`-Funktionen und `openResultUrl` sind Platzhalter für Ihre eigenen Screens und Ihren eigenen Ablauf. Das SDK liefert am Ende einer Authentisierung in `result.url` eine Adresse, die die App aufrufen soll, und zwar bei Erfolg und bei einem Fehler: Über sie erfährt der Dienst das Ergebnis. `tcTokenUrl` ist die Adresse, die der eID-Server der Gegenstelle liefert. Kommt sie als eID-Client-Link (`…/eID-Client?tcTokenURL=…`) aus einem Web-Ablauf, liest `tcTokenUrlFromEidClientLink(Uri)` sie heraus und gibt `null` zurück, wenn der Link nicht passt oder die Adresse nicht mit `https` beginnt.

Zum Aufräumen rufen Sie `await eid.stop()` und danach `eid.dispose()` auf. Weitere Möglichkeiten:

- `startChangePin()` startet eine PIN-Änderung (auch für die fünfstellige Transport-PIN).
- `setAccessRights(...)` schränkt die optionalen Zugriffsrechte ein, `getCertificate()` liefert das Zertifikat der Gegenstelle.
- `rawMessages` liefert jede Nachricht des SDK unverändert, `sendRaw(map)` sendet ein Kommando, das die typisierte API noch nicht kennt.
- `logger:` im Konstruktor schreibt Kommandos und Nachrichten mit, siehe unten.

### Der NFC-Dialog unter iOS und `interrupt()`

Unter iOS zeigt das System einen eigenen NFC-Dialog, solange das SDK die Karte liest. Laut SDK-Dokumentation schließt das SDK diesen Dialog nicht von selbst, wenn es nach PIN, CAN, PUK oder neuer PIN fragt (`PinRequested`, `CanRequested`, `PukRequested`, `NewPinRequested`). Die App muss ihn dann mit `eid.interrupt()` schließen, bevor sie ihren Eingabe-Screen zeigt; sonst liegt der Dialog über diesem Screen. Unter Android sendet `interrupt()` nichts, der Aufruf kann also auf beiden Plattformen stehen.

`interrupt()` ist nur direkt nach einem dieser vier Ereignisse erlaubt. Zu jedem anderen Zeitpunkt, etwa während `InsertCardRequested`, antwortet das SDK mit dem Ereignis `BadState`.

Auf einem iPhone 16 Pro mit iOS 27.2.1 ist das bestätigt: Der Dialog bleibt nach `PinRequested` offen, und die App lässt sich darunter nicht bedienen. Schließt die Nutzerin oder der Nutzer den Dialog über dessen eigene Schaltfläche, bricht das SDK den Ablauf ab und meldet `AuthenticationCompleted` mit `reason: User_Cancelled`.

### NFC-Status und NFC-Einstellungen

`AusweisAppNfc` sagt, ob das Gerät den Ausweis gerade lesen kann. Das funktioniert ohne das SDK: Es muss kein `AusweisApp` geben, und `start()` muss nicht aufgerufen sein. Fragen Sie ab, bevor Sie den Scan starten:

```dart
const AusweisAppNfc nfc = MethodChannelAusweisAppNfc();

switch (await nfc.status()) {
  case NfcStatus.unsupported:
    showNoNfc(); // das Gerät kann den Ausweis nicht lesen
  case NfcStatus.disabled:
    showNfcSwitchedOff(); // mit einem Knopf, der nfc.openSettings() aufruft
  case NfcStatus.available:
    startScan();
}
```

`NfcStatus.disabled` kommt nur unter Android vor. Dort öffnet `openSettings()` die NFC-Einstellungen des Systems und gibt `true` zurück. iOS hat keine solche Einstellung: Der Aufruf tut dort nichts und gibt `false` zurück, ohne Fehler. Siehe [Plattformunterschiede](#plattformunterschiede).

Der Status wird bei jedem Aufruf neu gelesen, Benachrichtigungen über Änderungen gibt es nicht. Fragen Sie erneut ab, wenn die App in den Vordergrund zurückkehrt (`AppLifecycleState.resumed`), zum Beispiel nach der Rückkehr aus den Einstellungen.

### Fehlerklassen

Das SDK meldet als Fehlercode, warum ein Ablauf gescheitert ist, zum Beispiel `Card_Removed` in `AuthResult.reason`. Seine Dokumentation führt 93 davon auf. `failureKind` ordnet sie wenigen Klassen zu, damit eine App für die häufigen Fälle einen eigenen Text zeigen kann und für alle übrigen einen allgemeinen Text mit dem rohen Code:

| `FailureKind` | Bedeutung | Codes |
| --- | --- | --- |
| `network` | ein Problem mit der Netzverbindung | die sieben Codes, für die die SDK-Dokumentation "Fix connection problems" empfiehlt, zum Beispiel `Get_TcToken_Network_Error` |
| `timeout` | etwas hat zu lange gedauert | `Check_Refresh_Address_Service_Timeout` und `Change_Pin_Input_Timeout`; außerdem der plugin-eigene Code `timeout` von `start()` und `stop()` |
| `userCancelled` | die Nutzerin oder der Nutzer hat abgebrochen, oder die App mit `cancel()` | `User_Cancelled` und die fünf weiteren Codes, die auf `User_Cancelled` enden |
| `cardConnection` | der Ausweis wurde entfernt, oder die Verbindung zu ihm ist gescheitert | `Card_Removed` und die acht Codes, für die die SDK-Dokumentation "Check ID card position" empfiehlt, zum Beispiel `Transmit_Card_Command_Failed` |
| `other` | alles Übrige, auch ein fehlender oder unbekannter Code | – |

```dart
case AuthenticationCompleted(:final result):
  switch (result.failureKind) {
    case null:
      showSuccess();
    case FailureKind.network:
      showNoConnection();
    case FailureKind.timeout:
      showTimeout();
    case FailureKind.userCancelled:
      closeScan();
    case FailureKind.cardConnection:
      showCardLost();
    case FailureKind.other:
      showGeneralError(code: result.reason); // der Code ist für den Support
  }
```

`failureKind` gibt es an `AuthResult` und an `ChangePinCompleted` (`null` bei Erfolg) und an jeder `AusweisAppException`, also auch an der `AusweisAppStartException`, die `start()` wirft. `FailureKind.fromReason(code)` ordnet einen rohen Code zu. Die rohen Werte (`reason`, `major`, `minor`, `code`) bleiben, wie sie sind. `AuthenticationStartFailed` trägt nur einen Freitext und hat keine Klasse.

Was die Klassen nicht sagen:

- Die Zuordnung richtet sich allein nach `reason`. Die SDK-Dokumentation führt die Werte von `minor` nicht auf, und auf einem iPhone meldete `minor` auch dann `cancellationByUser`, als der Ausweis weggezogen wurde.
- Das SDK hat keinen Code für "das Gerät ist offline". Dieser Fall kommt als einer der Netzwerkfehler an; `network` heißt deshalb "Verbindungsproblem", nicht streng "keine Internetverbindung". Auf einem iPhone im Flugmodus beobachtet: `reason: Get_TcToken_Network_Error`, und das Ergebnis trägt keine `url`.
- Quelle ist die Liste der Fehlercodes in der SDK-Dokumentation, `AusweisApp-community/docs/failurecodes/failurecodes.rst`. Die vollständige Tabelle steht in `lib/src/failure.dart`, und der Test `test/failure_test.dart` vergleicht sie mit dieser Datei.

### Die App ohne Gerät testen

`package:flutter_ausweisapp/testing.dart` enthält `FakeAusweisAppTransport`. Mit `AusweisApp(transport: fake)` lassen sich die eigenen Screens in Widget-Tests prüfen, ohne SDK und ohne Gerät.

Dieselbe Datei enthält `FakeAusweisAppNfc`. Lassen Sie Ihren Screen ein `AusweisAppNfc` entgegennehmen, und übergeben Sie im Test `FakeAusweisAppNfc(nfcStatus: NfcStatus.disabled)` statt `MethodChannelAusweisAppNfc()`; `nfcStatus` lässt sich während des Tests ändern, und `openSettingsCalls` zählt die Aufrufe von `openSettings()`.

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
4. **NFC bleibt optional.** Das Android-Paket des SDK trägt `<uses-feature android:name="android.hardware.nfc" android:required="false" />` ein, und so kommt es im zusammengeführten Manifest der App an (geprüft an der gebauten Beispiel-App mit SDK 2.6.3: `aapt2 dump badging` meldet `uses-feature-not-required: name='android.hardware.nfc'`). Die App bleibt damit auf Geräten ohne NFC installierbar, und es gibt nichts zu überschreiben. Tragen Sie die Fähigkeit nicht mit `android:required="true"` in Ihr eigenes Manifest ein; fragen Sie stattdessen zur Laufzeit `AusweisAppNfc.status()` ab.

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
| `AusweisAppNfc.status()` | `unsupported` (kein NFC-Adapter), `disabled` (NFC ausgeschaltet) oder `available` | `unsupported` oder `available`, je nachdem, ob das Gerät Tags lesen kann; nie `disabled`, weil sich NFC nicht ausschalten lässt |
| `AusweisAppNfc.openSettings()` | öffnet die NFC-Einstellungen des Systems und gibt `true` zurück; `false`, wenn das Gerät keinen solchen Screen anbietet | tut nichts und gibt `false` zurück, ohne Fehler; iOS hat keine NFC-Einstellung |
| Ausweis wird während des Lesens weggezogen | auf einem Gerät noch ungeprüft | kein `Paused`; der Ablauf endet mit `AuthenticationCompleted` ohne Erfolg, und die Anmeldung muss neu beginnen (auf einem iPhone beobachtet) |

Besonderheiten unter Android:

- Nach `stop()` beendet das SDK seinen eigenen Prozess. Ein `start()` direkt danach wartet bis zu 3 Sekunden, bis dieser Prozess beendet ist, und bindet erst dann neu. Sonst würde Android den Dienst erst nach einer Wartezeit von etwa 10 Sekunden neu starten.
- Bekannte Grenze: Wird das Plugin an eine Activity gehängt, die schon im Vordergrund ist (Add-to-App mit einem später eingefügten `FlutterFragment`), schaltet sich der NFC-Lesemodus erst nach dem nächsten Pausieren und Fortsetzen ein. Mit einer normalen `FlutterActivity` tritt das nicht auf.

## Lebenszyklus und Fehler

- **Nur ein `AusweisApp` zur gleichen Zeit.** Das SDK existiert einmal pro Prozess. Zwei Objekte, die gleichzeitig arbeiten, werden nicht unterstützt. Ereignisse erhält immer das Objekt, das zuletzt `start()` aufgerufen hat. Der übliche Wechsel zwischen zwei Screens funktioniert trotzdem: Hat der neue Screen bei seinem `AusweisApp` schon `start()` aufgerufen, wenn der alte Screen `dispose()` aufruft, stoppt das alte Objekt das SDK des neuen nicht.
- `start()` hat eine Frist von standardmäßig 15 Sekunden und wirft `AusweisAppStartException` (Codes `start_failed`, `timeout`, `api_level`). Der erste Schritt von `start()` stellt das API-Level 3 ein.
- `stop()` wartet höchstens 15 Sekunden und wirft sonst `AusweisAppTransportException` (Code `timeout`). Läuft noch ein Stoppen, zum Beispiel nach einem gescheiterten `start()`, wartet `stop()` auf dieses.
- `dispose()` löst das Stoppen aus, wartet aber nicht darauf. Das ist für `State.dispose()` gedacht, das nicht warten kann. Ein neues `AusweisApp`, das danach startet, wartet selbst, bis dieses Stoppen beendet ist.
- Kommandos bei nicht laufendem SDK werfen `AusweisAppNotRunningException`. Meldet das SDK selbst bei einem Kommando, dass es nicht läuft, wirft das Kommando ebenfalls `AusweisAppNotRunningException`; `isRunning` steht danach auf `false`, und `start()` startet das SDK neu. Transportfehler beim Senden werfen `AusweisAppTransportException`.
- Fehlermeldungen des SDK (`BAD_STATE`, `INTERNAL_ERROR`, `INVALID`, `UNKNOWN_COMMAND`) kommen als Ereignisse an: `BadState`, `InternalError`, `InvalidCommand`, `UnknownCommand`. Nachrichten, die das Plugin nicht kennt, kommen als `UnknownMessageReceived` mit dem Roh-JSON.
- Ein fachlich gescheiterter Ablauf (falsche PIN, Abbruch, gesperrte Karte) ist **keine** Ausnahme, sondern ein normales Ereignis, etwa `AuthenticationCompleted` mit einem Ergebnis, dessen `isSuccess` false ist.
- Nach `stop()` mitten in einem Ablauf kommt kein `AuthenticationCompleted` und kein `ChangePinCompleted` mehr (auf einem iPhone beobachtet). Warten Sie nach `stop()` nicht auf ein Abschluss-Ereignis.

## Umgang mit PIN, CAN und PUK

- Das Plugin schreibt Kommandos mit Geheimnissen nie ins Log. Das Mitschreiben von Kommandos und Nachrichten ist standardmäßig aus (`logger:` im Konstruktor von `AusweisApp`). Wenn Sie es einschalten, ersetzt das Plugin PIN, CAN, PUK und die Werte von HTTP-Headern durch `***`.
- Adressen ersetzt das Plugin im Log nicht: Die `tcTokenURL` im Kommando `RUN_AUTH` und die Ergebnis-Adresse in der Nachricht `AUTH` stehen im Klartext da. Beide enthalten in der Regel ein Sitzungs-Token. Das Mitschreiben ist deshalb nur für die Entwicklung gedacht; schalten Sie es in ausgelieferten Apps nicht ein.
- Unter Android überschreibt das Plugin das Zeichenfeld nach dem Senden mit Nullen.
- Bekannte Grenze: Die Eingabe wird in Flutter als Dart-String erfasst und lässt sich dort nicht gezielt aus dem Speicher löschen. Das gilt für jeden Flutter-Weg.

## Simulator-Karte

Das SDK bringt eine virtuelle Karte mit. Sie liegt in einem eingebauten Leser namens `Simulator` und wird mit `eid.setCard('Simulator')` eingelegt, zum Beispiel wenn `InsertCardRequested` kommt. Sie funktioniert nur gegen Testumgebungen, etwa den Governikus-Testdienst `https://test.governikus-eid.de/Autent-DemoApplication/api/eid/request`, und dafür braucht `startAuthentication` den Parameter `developerMode: true`.

Der Leser `Simulator` meldet sich als Leser mit eigener Tastatur. PIN, CAN, PUK und neue PIN müssen deshalb **ohne Wert** gesendet werden: `eid.setPin(null)`. Mit einem Wert lehnt das SDK die Eingabe jedes Mal ab.

Die Simulator-Karte läuft auch im Emulator und im Simulator, braucht aber Netzzugriff auf den Testdienst.

**Echte Ausweise brauchen einen Produktivdienst.** Am Governikus-Testdienst wird ein echter Personalausweis gelesen und die PIN angenommen; danach endet der Ablauf mit dem Grund `Process_Certificates_From_Eac2_Cvc_Chain_Missing`, weil der Testdienst Test-Zertifikate verwendet. Umgekehrt lehnt das SDK einen Produktivdienst ab, solange `developerMode: true` gesetzt ist, laut SDK-Dokumentation mit dem Grund `Pre_Verification_No_Test_Environment`. Für einen Produktivdienst lassen Sie `developerMode` auf dem Standardwert `false`.

## Entwicklung

Tests in diesem Repository:

- `flutter test` im Wurzelverzeichnis führt die Unit-Tests aus, ohne Gerät.
- `flutter test` im Verzeichnis `example/` führt die Widget-Tests der Beispiel-App aus.
- `flutter test integration_test -d <Gerät>` im Verzeichnis `example/` führt die Integrationstests auf einem Emulator, Simulator oder Gerät aus. Der Test mit der Simulator-Karte braucht Netzzugriff auf den Governikus-Testdienst. Der Test des NFC-Status erwartet dort keinen bestimmten Wert; ein Emulator oder Simulator hat kein NFC und antwortet mit `unsupported`.

Die Beispiel-App in `example/` ist eine einfache Testoberfläche, die alle Abläufe anstößt. Wie Sie sie auf einem Gerät starten, steht in `example/README.de.md`; die Prüfliste für echte Geräte steht in `docs/geraetetest.md`.

**Hot Restart.** Nach einem Hot Restart läuft das native SDK weiter. `start()` kehrt dann sofort zurück. Ein laufender Ablauf bleibt bestehen und lässt sich mit `cancel()` beenden.

## SDK-Update

Die SDK-Version steht an zwei Stellen: in `android/build.gradle.kts` (`com.governikus:ausweisapp:2.6.3`) und in `ios/flutter_ausweisapp/Package.swift` (`exact: "2.6.3"`). Lesen Sie vor dem Anheben das SDK-Changelog unter `AusweisApp-community/docs/sdk/changelog.rst`, weil das Plugin das Protokoll selbst umsetzt und Änderungen dort nachzieht. Das Plugin stellt beim Start das API-Level 3 ein, damit ein neueres SDK das Verhalten nicht stillschweigend ändert.

Zwei weitere Prüfungen gehören zu einem Update:

- Ersetzen Sie `AusweisApp-community/docs/failurecodes/failurecodes.rst` durch die Datei der neuen SDK-Version, und führen Sie `flutter test` aus. `test/failure_test.dart` schlägt fehl, wenn es einen Code aus `lib/src/failure.dart` nicht mehr gibt oder wenn ein neuer Code zu einer der Klassen gehört.
- Bauen Sie die Beispiel-App, und prüfen Sie, dass NFC weiterhin eine optionale Fähigkeit ist: `aapt2 dump badging example/build/app/outputs/flutter-apk/app-debug.apk` muss `uses-feature-not-required: name='android.hardware.nfc'` melden. Macht eine neue SDK-Version NFC zur Pflicht-Fähigkeit, muss der Eintrag mit `<uses-feature android:name="android.hardware.nfc" android:required="false" tools:replace="android:required" />` überschrieben werden, und diese README muss sagen, wo.

## Abgrenzung: Login-Ablauf der App

Dieses Plugin kümmert sich nur um den Kartenzugriff und nimmt eine `tcTokenURL` entgegen. Wie die App diese Adresse aus ihrem Login-Ablauf gewinnt (zum Beispiel aus einem Identity-Provider wie Keycloak mit angebundenem BundID-Konto) und den Login danach abschließt, gehört zur App. Ob der jeweilige Dienst diesen Weg zulässt, müssen Sie mit dessen Betreiber klären. Unabhängig davon lässt sich das Plugin vollständig gegen den Governikus-Testdienst entwickeln.

Wie Sie diesen Ablauf um das Plugin herum bauen, mit einer Web-Ansicht, die den Ausweis-Schritt an das SDK übergibt, beschreibt [docs/integration.de.md](docs/integration.de.md) Schritt für Schritt.

## Lizenz

Copyright © 2026 Open Reply GmbH.

Das Plugin steht unter der Open-Source-Lizenz für die Europäische Union (EUPL) in Version 1.2. Der Lizenztext steht in der Datei `LICENSE`.

Das eingebundene AusweisApp-SDK von Governikus steht ebenfalls unter der EUPL 1.2. Wer eine App mit diesem Plugin ausliefert, verbreitet das SDK mit. Was dabei zu beachten ist, steht in `NOTICE.de.md`.
