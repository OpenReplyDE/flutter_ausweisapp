# flutter_ausweisapp_example

Die Beispiel-App ist eine einfache Testoberfläche für das Plugin `flutter_ausweisapp`. Sie stößt alle Abläufe an (Authentisierung, PIN-Änderung, PIN, CAN, PUK, Zugriffsrechte) und zeigt jedes Ereignis des Plugins im Abschnitt „Protokoll" an. Mit ihr führen Sie auch die Prüfliste `../docs/geraetetest.md` auf echten Geräten durch.

Voreingestellt ist der Governikus-Testdienst `https://test.governikus-eid.de/Autent-DemoApplication/api/eid/request` mit eingeschaltetem Entwicklermodus.

## Auf einem Android-Gerät starten

1. Das Gerät per USB anschließen, Entwickleroptionen und USB-Debugging einschalten. Das Gerät muss NFC mit Extended Length unterstützen.
2. `flutter devices` zeigt die Geräte-ID.
3. Im Verzeichnis `example/` ausführen: `flutter run --release -d <Geräte-ID>`.

Die Release-Variante ist mit dem Debug-Schlüssel signiert, damit sie sich ohne eigene Signierung starten lässt.

## Auf einem iPhone starten

Die App ist nicht für Ihr Apple-Team signiert. Richten Sie vor dem ersten Start Folgendes ein:

1. `example/ios/Runner.xcworkspace` in Xcode öffnen.
2. Im Ziel „Runner" unter „Signing & Capabilities" Ihr eigenes Team wählen und eine eigene, eindeutige Bundle-ID eintragen (die voreingestellte gehört nicht Ihnen).
3. Dort die Fähigkeit „Near Field Communication Tag Reading" hinzufügen. Sie muss auch am App-Identifier im Apple-Entwicklerkonto aktiv sein. Die Datei `example/ios/Runner/Runner.entitlements` enthält den dazu passenden Eintrag `TAG` bereits, die `Info.plist` die Kartenkennung und den Nutzungstext.
4. Das iPhone anschließen, `flutter devices` zeigt die Geräte-ID. Im Verzeichnis `example/` ausführen: `flutter run --release -d <Geräte-ID>`.

Das iPhone braucht iOS 17.0 oder neuer. Die Beispiel-App schaltet Swift Package Manager in ihrer `pubspec.yaml` ein (`flutter` → `config` → `enable-swift-package-manager: true`).

Hinweis zum Bauen am 24.11.2026: Mit Flutter 3.41.7 und Xcode 27.2 schlägt `flutter build ios --simulator` fehl (Flutters Aufruf `lipo -verify_arch` wird abgelehnt), auch für eine leere App. Starts auf einen konkreten Simulator oder ein Gerät (`flutter run -d <Geräte-ID>`) funktionieren.

## Bedienung

1. „SDK starten" antippen; oben steht dann „SDK läuft".
2. „Authentisierung starten" antippen, die Ereignisse erscheinen im Protokoll.
3. PIN, CAN und PUK tragen Sie im Feld „Eingabe" ein und senden sie mit den vier Schaltflächen darunter.

Mit der Simulator-Karte des SDK (Schaltfläche „Simulator-Karte einlegen") läuft eine ganze Authentisierung ohne echten Ausweis. Lassen Sie dann das Feld „Eingabe" **leer** und tippen Sie „als PIN senden": Der Simulator meldet sich als Leser mit eigener Tastatur, und das SDK lehnt jede PIN mit Wert ab.

## Tests

- `flutter test` im Verzeichnis `example/` führt die Widget-Tests aus.
- `flutter test integration_test -d <Geräte-ID>` führt die Integrationstests aus; der Test mit der Simulator-Karte braucht Netzzugriff auf den Governikus-Testdienst.
