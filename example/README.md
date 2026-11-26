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

Unter iOS steht im Abschnitt „PIN, CAN, PUK" zusätzlich der Schalter „NFC-Dialog bei PIN-, CAN- und PUK-Abfrage automatisch schließen". Er ist voreingestellt an und sendet `INTERRUPT`, sobald das SDK nach PIN, CAN, PUK oder neuer PIN fragt. Sonst bleibt der NFC-Dialog des Systems offen, und die App lässt sich darunter nicht bedienen (auf einem iPhone 16 Pro mit iOS 27.2.1 bestätigt). Mehr dazu steht im Abschnitt „Der NFC-Dialog unter iOS und `interrupt()`" der `README.md` des Plugins.

Das Protokoll zeigt zu jedem Ereignis die wichtigsten Felder, etwa `retryCounter` oder das Ergebnis einer Authentisierung. Adressen zeigt es nicht, weil sie ein Sitzungs-Token enthalten können, sondern nur, ob eine vorhanden ist.

Mit der Simulator-Karte des SDK (Schaltfläche „Simulator-Karte einlegen") läuft eine ganze Authentisierung ohne echten Ausweis. Lassen Sie dann das Feld „Eingabe" **leer** und tippen Sie „als PIN senden": Der Simulator meldet sich als Leser mit eigener Tastatur, und das SDK lehnt jede PIN mit Wert ab.

## Anmeldung im Browser

Mit dem Abschnitt „Anmeldung im Browser“ prüfen Sie den Ablauf gegen einen echten Dienst, zum Beispiel einen Login, der zur Online-Ausweisfunktion weiterleitet. Am Governikus-Testdienst gelingt die Authentisierung nur mit einer Testkarte; ein echter Personalausweis braucht einen Produktivdienst.

1. Die Adresse des Logins im Feld „Login-Adresse“ eintragen.
2. „Im Browser anmelden“ antippen. Die App öffnet die Seite in einer eingebetteten Web-Ansicht.
3. Auf der Seite die Anmeldung mit dem Online-Ausweis wählen. Sobald die Seite den Ausweis-Client starten will, schließt die App die Web-Ansicht, startet bei Bedarf das SDK und beginnt die Authentisierung.
4. Wie gewohnt „Akzeptieren“ antippen, den Ausweis anhalten und die PIN senden.
5. Nach einer erfolgreichen Authentisierung öffnet die App die Rückkehr-Adresse in derselben Web-Ansicht. Dort schließt der Dienst den Login ab. Scheitert die Authentisierung, bleibt die App beim Protokoll, damit der Grund sichtbar ist, und öffnet die Rückkehr-Adresse nicht.
6. Leitet der Dienst am Ende auf das Schema einer App weiter (zum Beispiel `de.example.app:/oauth2redirect?code=…`), schließt die Beispiel-App die Web-Ansicht und meldet im Protokoll `Weiterleitung an eine App empfangen` mit dem Schema und den Namen der Parameter. Die Werte zeigt sie nicht. In Ihrer App fangen Sie diese Weiterleitung ab und schließen damit den Login ab.

Die Anmeldung im Browser startet die Authentisierung immer ohne Entwicklermodus, unabhängig vom Schalter: Das SDK lehnt einen Produktivdienst im Entwicklermodus sofort ab. Der Schalter gilt nur für „Authentisierung starten“.

Die App erkennt den Start des Ausweis-Clients an einem Link der Form `…/eID-Client?tcTokenURL=https://…`. Startet ein Dienst den Client auf anderem Weg, greift die Übernahme nicht; ob ein bestimmter Dienst diesen Weg zulässt, müssen Sie mit dessen Betreiber klären.

Die Web-Ansicht ist nur ein Hilfsmittel der Beispiel-App. Das Plugin selbst enthält keine Web-Ansicht; in Ihrer App bauen Sie diesen Teil selbst.

## Tests

- `flutter test` im Verzeichnis `example/` führt die Widget-Tests aus.
- `flutter test integration_test -d <Geräte-ID>` führt die Integrationstests aus; der Test mit der Simulator-Karte braucht Netzzugriff auf den Governikus-Testdienst.
