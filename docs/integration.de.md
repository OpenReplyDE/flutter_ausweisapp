# Das Plugin in eine App einbinden

English version: [integration.md](integration.md)

Diese Anleitung richtet sich an Entwicklerinnen und Entwickler, die `flutter_ausweisapp` in eine bestehende Flutter-App einbauen, deren Login über eine Webseite läuft, zum Beispiel über einen Identity-Provider, der den Online-Ausweis als Anmeldeweg anbietet. Sie beschreibt, was die App um das Plugin herum bauen muss. Die API des Plugins und die Einrichtung der Plattformen stehen in der [README](../README.de.md).

## Was sich für die App ändert

Ohne das Plugin übergibt die Login-Seite den Ausweis-Schritt an die separate AusweisApp. Mit dem Plugin erledigt die App diesen Schritt selbst:

1. Die App öffnet die Login-Seite in einer eingebetteten Web-Ansicht.
2. Wählt die Nutzerin oder der Nutzer den Online-Ausweis, navigiert die Seite zu einem eID-Client-Link (`…/eID-Client?tcTokenURL=https://…`). Die App fängt diese Navigation ab und gibt die `tcTokenURL` an das Plugin.
3. Das Plugin meldet, was das SDK braucht: die Bestätigung der Zugriffsrechte, den Ausweis, die PIN. Die App zeigt dafür ihre eigenen Screens.
4. Am Ende der Authentisierung liefert das SDK eine Adresse. Die App öffnet sie in derselben Web-Ansicht, damit der Dienst das Ergebnis in der Sitzung erfährt, die den Login begonnen hat.
5. Die Login-Seite schließt ab und leitet auf das eigene Schema der App weiter (zum Beispiel `com.example.app:/oauth2redirect?code=…`). Die App fängt auch diese Navigation ab und schließt ihren Login mit dem Code ab, wie bisher.

Dieser Ablauf ist auf einem iPhone mit einem echten Personalausweis gegen einen Produktivdienst bis zur Weiterleitung in Schritt 5 gelaufen; siehe [geraetetest.md](geraetetest.md). Ob ein bestimmter Dienst ihn zulässt, müssen Sie mit dessen Betreiber klären.

## Voraussetzungen

| Voraussetzung | Wert |
| --- | --- |
| Flutter | 3.41 oder neuer (Dart 3.11) |
| Android | `minSdk` 28 (Android 9), Geräte mit Extended-Length-NFC |
| iOS | Deployment Target 17.0, Swift Package Manager für die App eingeschaltet, NFC-Entitlement |
| Login | die Login-Seite läuft in einer Web-Ansicht, die die App steuert |

Zwei davon sind Entscheidungen für das Produkt, nicht nur Einstellungen:

- **iOS 17.** Das SDK läuft auf älteren Versionen nicht. Unterstützt die App heute ältere Versionen, muss sie ihre Mindestversion anheben.
- **Web-Ansicht statt Systembrowser.** Login-Bibliotheken, die den Systembrowser öffnen (`ASWebAuthenticationSession` unter iOS, Custom Tabs unter Android), lassen die App den eID-Client-Link nicht sehen. Der Login muss in einer Web-Ansicht wie `webview_flutter` laufen, und die App übernimmt die Weiterleitung und den Token-Tausch selbst.

## 1. Abhängigkeit eintragen

Das Plugin liegt nicht auf pub.dev. Verweisen Sie auf das Git-Repository und legen Sie einen Tag fest:

```yaml
dependencies:
  flutter_ausweisapp:
    git:
      url: git@github.com:OpenReplyDE/flutter_ausweisapp.git
      ref: v0.0.1
```

Build-Rechner brauchen Lesezugriff auf das Repository, solange es privat ist.

## 2. Plattformen einrichten

Folgen Sie den Abschnitten „Einrichtung Android“ und „Einrichtung iOS“ in der [README](../README.de.md). In Kürze:

- Android: `minSdk = 28`; eine eigene `Application`-Klasse überspringt ihre Initialisierung in dem Prozess, dessen Name auf `ausweisapp2_service` endet.
- iOS: Swift Package Manager in der `pubspec.yaml` der App einschalten, Deployment Target 17.0, NFC-Entitlement `TAG` und die beiden `Info.plist`-Einträge.

Plugins der App, die noch kein Swift Package anbieten, bindet Flutter weiterhin über CocoaPods ein.

## 3. Den Login-Ablauf bauen

Die folgende Klasse enthält den ganzen Ablauf. Sie braucht neben dem Plugin das Paket `webview_flutter`. Die Callbacks stehen für die eigenen Screens der App und für ihren bestehenden Token-Tausch.

```dart
import 'dart:async';

import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum EidInput { pin, can, puk }

/// Führt einen Web-Login aus und übergibt dessen Ausweis-Schritt an das
/// AusweisApp-SDK.
class EidLoginFlow {
  EidLoginFlow({
    required this.loginUrl,
    required this.redirectScheme,
    required this.onAccessRights,
    required this.onCardNeeded,
    required this.onInput,
    required this.onRedirect,
    required this.onFailed,
  });

  /// Die vollständige Login-Adresse des Dienstes mit allen Parametern.
  final Uri loginUrl;

  /// Das Schema der Redirect-Adresse der App, zum Beispiel `com.example.app`.
  final String redirectScheme;

  /// Zugriffsrechte zeigen; danach `eid.accept()` oder `eid.cancel()`.
  final void Function(AccessRights rights) onAccessRights;

  /// Bitten, den Ausweis an das Gerät zu halten.
  final void Function() onCardNeeded;

  /// Eingabe-Screen zeigen; danach `eid.setPin`, `setCan` oder `setPuk`.
  final void Function(EidInput input, int? retryCounter) onInput;

  /// Der Login ist fertig: Die Adresse trägt den Code für den Token-Tausch.
  final void Function(Uri redirect) onRedirect;

  /// Die Authentisierung ist gescheitert oder wurde abgebrochen; [reason]
  /// ist der Code des SDK.
  final void Function(String? reason) onFailed;

  final eid = AusweisApp();
  late final WebViewController web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(onNavigationRequest: _onNavigation),
    );
  StreamSubscription<AusweisAppEvent>? _events;

  Future<void> start() async {
    // Vor start() abonnieren, damit kein Ereignis verloren geht.
    _events = eid.events.listen(_onEvent);
    await eid.start();
    await web.loadRequest(loginUrl);
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final url = Uri.tryParse(request.url);
    if (url == null) return NavigationDecision.navigate;

    // Die Seite will den Ausweis-Client starten: Das SDK übernimmt.
    final tcTokenUrl = tcTokenUrlFromEidClientLink(url);
    if (tcTokenUrl != null) {
      unawaited(eid.startAuthentication(tcTokenUrl: tcTokenUrl));
      return NavigationDecision.prevent;
    }

    // Die Login-Seite ist fertig und leitet an die App weiter.
    if (url.scheme == redirectScheme) {
      onRedirect(url);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _onEvent(AusweisAppEvent event) {
    switch (event) {
      case AccessRightsRequested(:final rights):
        onAccessRights(rights);
      case InsertCardRequested():
        onCardNeeded();
      case PinRequested(:final reader):
        unawaited(eid.interrupt()); // schließt unter iOS den NFC-Dialog
        onInput(EidInput.pin, reader.card?.retryCounter);
      case CanRequested():
        unawaited(eid.interrupt());
        onInput(EidInput.can, null);
      case PukRequested():
        unawaited(eid.interrupt());
        onInput(EidInput.puk, null);
      case AuthenticationCompleted(:final result):
        // Die Adresse meldet dem Dienst das Ergebnis, auch einen Fehlschlag.
        if (result.url case final url?) unawaited(web.loadRequest(url));
        if (!result.isSuccess) onFailed(result.reason);
      case AuthenticationStartFailed(:final error):
        onFailed(error);
      default:
        break;
    }
  }

  Future<void> dispose() async {
    await _events?.cancel();
    await eid.stop();
    await eid.dispose();
  }
}
```

Zeigen Sie die Web-Ansicht mit `WebViewWidget(controller: flow.web)`, solange die Nutzerin oder der Nutzer auf der Login-Seite ist, und die eigenen Screens der App, solange das SDK arbeitet. Setzen Sie `developerMode` für einen Produktivdienst nicht; das SDK lehnt ihn dort ab.

## 4. Den Login abschließen

`onRedirect` erhält die Redirect-Adresse mit den Parametern `code` und `state`. Ab hier ist nichts mehr ausweisspezifisch: Prüfen Sie `state` gegen den Wert, den die App gesendet hat, und tauschen Sie `code` am Token-Endpunkt zusammen mit dem PKCE-Verifier ein. `state` und die PKCE-Werte erzeugt die App selbst, wenn sie `loginUrl` zusammenbaut, weil in diesem Ablauf keine Login-Bibliothek das übernimmt.

## Was die Screens abdecken müssen

| Ereignis | Was die App zeigt | Danach |
| --- | --- | --- |
| `AccessRightsRequested` | die Daten, die der Dienst anfragt | `eid.accept()` oder `eid.cancel()` |
| `InsertCardRequested` | den Hinweis, den Ausweis an das Gerät zu halten | nichts; das SDK macht von selbst weiter |
| `PinRequested` | die PIN-Eingabe, mit `retryCounter`, wenn er unter 3 liegt | `eid.setPin(pin)` |
| `CanRequested` | die CAN-Eingabe (sechs Ziffern auf der Vorderseite des Ausweises) | `eid.setCan(can)` |
| `PukRequested` | die PUK-Eingabe (aus dem PIN-Brief) | `eid.setPuk(puk)` |
| `AuthenticationCompleted` mit `isSuccess == false` | eine Fehler- oder Abbruchmeldung | den Login neu beginnen |

Nach einer falschen PIN fragt das SDK erneut, mit niedrigerem `retryCounter`; bei 1 fragt es zuerst nach der CAN, bei 0 nach der PUK. Eine richtige PIN setzt den Zähler wieder auf 3.

## Verhalten unter iOS, das Sie einplanen müssen

Auf einem iPhone 16 Pro mit iOS 27.2.1 beobachtet:

- Solange das SDK auf den Ausweis wartet oder ihn liest, zeigt das System seinen NFC-Dialog, und die App lässt sich darunter nicht bedienen. Die App braucht in diesem Zustand keinen eigenen Abbrechen-Knopf; abgebrochen wird im Dialog, und die App erhält `AuthenticationCompleted` mit `reason: User_Cancelled`.
- Der Dialog bleibt offen, wenn das SDK nach PIN, CAN oder PUK fragt. `eid.interrupt()` schließt ihn; deshalb ruft die Klasse oben es vor jeder Eingabe auf. Nach dem Senden der Eingabe erscheint der Dialog erneut, und der Ausweis wird noch einmal an das Gerät gehalten.
- Wird der Ausweis während des Lesens weggezogen, scheitert der Ablauf (`AuthenticationCompleted` ohne Erfolg). Der Login muss neu beginnen.
- Die Texte des Dialogs kommen über den Parameter `userInfoMessages` von `startAuthentication`.

Unter Android gibt es keinen Systemdialog; die App zeigt ihren eigenen Hinweis, solange der Ausweis gelesen wird. Android ist auf echter Hardware noch nicht getestet.

## Testen

- **Screens ohne Gerät:** `AusweisApp(transport: FakeAusweisAppTransport())` aus `package:flutter_ausweisapp/testing.dart` lässt Widget-Tests beliebige SDK-Nachrichten an die Screens der App schicken.
- **Ohne Ausweis:** Die Simulator-Karte des SDK funktioniert am Governikus-Testdienst mit `developerMode: true`; siehe „Simulator-Karte“ in der README.
- **Echte Ausweise** funktionieren nur gegen einen Produktivdienst und ohne Entwicklermodus. Testausweise der Test-PKI funktionieren gegen Testdienste.
- Die Beispiel-App in `example/` enthält den hier beschriebenen Ablauf als Testwerkzeug („Anmeldung im Browser“).

## Vor der Veröffentlichung

- [NOTICE.de.md](../NOTICE.de.md) lesen: Eine App, die das Plugin ausliefert, verbreitet das SDK und muss die Pflichten aus der EUPL erfüllen.
- Mit dem Betreiber des Login-Dienstes klären, ob der eingebettete Ablauf zulässig ist.
- Den Gerätetest unter Android abschließen; siehe [geraetetest.md](geraetetest.md).
