# Lizenzhinweis

Dieser Hinweis richtet sich an alle, die eine App mit dem Plugin `flutter_ausweisapp` ausliefern, und an deren Rechtsabteilung. Er ist keine Rechtsberatung.

## Das SDK steht unter der EUPL 1.2

Das Plugin enthält das AusweisApp-SDK von Governikus, Version 2.6.3, als fertiges Android-Paket (`com.governikus:ausweisapp`) und als iOS-Swift-Package (`https://github.com/Governikus/AusweisApp2-SDK-iOS`). Der Quellcode des SDK steht unter der Open-Source-Lizenz für die Europäische Union (EUPL) in Version 1.2.

Wer eine App mit diesem Plugin ausliefert, verbreitet damit eine Kopie des SDK. Dafür gelten die Pflichten aus Artikel 5 der EUPL. Die App muss deshalb:

1. die Urheber- und Lizenzhinweise des SDK beifügen,
2. den Lizenztext mitliefern (er steht in `AusweisApp-community/LICENSE.txt`),
3. auf den Quellcode des SDK verweisen: `https://github.com/Governikus/AusweisApp`.

Diese Pflichten gelten unabhängig davon, wie das Plugin selbst lizenziert ist.

## Zusatzvereinbarungen zur AusweisApp

Dem iOS-Binärpaket liegt eine Fassung bei, die zusätzlich zur EUPL „Zusatzvereinbarungen zur AusweisApp" enthält: `AusweisApp-community/LICENSE.officially.txt`, Abschnitt B. Nach Paragraph 3 dienen die AusweisApp und alle ihre Bestandteile ausschließlich der Online-Ausweisfunktion, und nach Paragraph 6 sind die Zeichen „AusweisApp" und die zugehörigen Grafiken als Marken des Bundes geschützt. Paragraph 1 Absatz 3 hält fest, dass die Zusatzvereinbarungen die Rechte und Pflichten aus der EUPL unberührt lassen. Lesen Sie den Abschnitt vollständig, bevor Sie eine App ausliefern.

## Was offen ist

Die EUPL enthält eine Copyleft-Klausel für Kopien und Bearbeitungen des SDK. Wann eigener Code als Bearbeitung gilt, lässt die EUPL ausdrücklich offen und verweist auf das anwendbare Urheberrecht. Das Plugin verändert das SDK nicht und spricht es nur über die dokumentierte JSON-Schnittstelle an; es ist nach der Protokoll-Dokumentation geschrieben, nicht aus dem Code der offiziellen Wrapper übertragen.

**Ob Plugin und App quelloffen sein müssen, ist offen und keine Aussage dieses Dokuments.** Diese Frage ist vor der Veröffentlichung der App mit der Rechtsabteilung und am besten direkt mit Governikus zu klären.

## Die Datei LICENSE

Die Datei `LICENSE` des Plugins bleibt bis zur Klärung dieser Frage ein Platzhalter. Das Plugin trägt bewusst noch keine eigene Lizenz, und `pubspec.yaml` verhindert mit `publish_to: none` eine Veröffentlichung auf pub.dev.
