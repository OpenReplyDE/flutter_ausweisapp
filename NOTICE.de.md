# Lizenzhinweis

English version: [NOTICE.md](NOTICE.md)

Dieser Hinweis richtet sich an alle, die das Plugin `flutter_ausweisapp` nutzen, weitergeben oder eine App damit ausliefern, und an deren Rechtsabteilung. Er ist keine Rechtsberatung.

## Das Plugin steht unter der EUPL 1.2

Copyright © 2026 Open Reply GmbH.

Das Plugin ist Open Source und steht unter der Open-Source-Lizenz für die Europäische Union (EUPL) in Version 1.2. Der vollständige Lizenztext steht in der Datei `LICENSE` in diesem Repository.

Die EUPL enthält eine Copyleft-Klausel: Wer das Plugin oder eine Bearbeitung davon weitergibt, muss dabei die Bedingungen aus Artikel 5 der EUPL einhalten. Dazu gehören die Weitergabe unter der EUPL und die Bereitstellung des Quellcodes.

## Das SDK steht ebenfalls unter der EUPL 1.2

Das Plugin bindet das AusweisApp-SDK von Governikus, Version 2.6.3, als fertiges Android-Paket (`com.governikus:ausweisapp`) und als iOS-Swift-Package (`https://github.com/Governikus/AusweisApp2-SDK-iOS`) ein. Das SDK ist nicht Teil dieses Repositorys; die Build-Werkzeuge laden es beim Bau der App. Der Quellcode des SDK steht unter der EUPL 1.2.

Wer eine App mit diesem Plugin ausliefert, verbreitet damit eine Kopie des SDK. Dafür gelten die Pflichten aus Artikel 5 der EUPL. Die App muss deshalb:

1. die Urheber- und Lizenzhinweise des SDK beifügen,
2. den Lizenztext mitliefern,
3. auf den Quellcode des SDK verweisen: `https://github.com/Governikus/AusweisApp`.

Die Lizenzbestimmungen, die Governikus dem SDK beilegt, liegen in diesem Repository unter `AusweisApp-community/LICENSE.txt`. Im selben Ordner liegen unter `AusweisApp-community/docs/sdk/` die Protokoll-Dokumentation des SDK, nach der das Plugin geschrieben ist, und unter `AusweisApp-community/docs/failurecodes/failurecodes.rst` die Liste der Fehlercodes, die diese Dokumentation einbindet; beide stammen aus dem Governikus-Repository und stehen ebenfalls unter der EUPL 1.2.

## Zusatzvereinbarungen zur AusweisApp

Dem iOS-Binärpaket liegt eine Fassung bei, die zusätzlich zur EUPL „Zusatzvereinbarungen zur AusweisApp“ enthält. Sie liegt in diesem Repository unter `AusweisApp-community/LICENSE.officially.txt`, Abschnitt B. Nach Paragraph 3 dienen die AusweisApp und alle ihre Bestandteile ausschließlich der Online-Ausweisfunktion, und nach Paragraph 6 sind die Zeichen „AusweisApp“ und die zugehörigen Grafiken als Marken des Bundes geschützt. Paragraph 1 Absatz 3 hält fest, dass die Zusatzvereinbarungen die Rechte und Pflichten aus der EUPL unberührt lassen. Lesen Sie den Abschnitt vollständig, bevor Sie eine App ausliefern.

## Was für Ihre App offen bleibt

Die Copyleft-Klausel der EUPL gilt für Kopien und Bearbeitungen. Wann eigener Code als Bearbeitung gilt, lässt die EUPL ausdrücklich offen und verweist auf das anwendbare Urheberrecht.

Das Plugin verändert das SDK nicht und spricht es nur über die dokumentierte JSON-Schnittstelle an. Es ist nach der Protokoll-Dokumentation des SDK entworfen und nicht aus dem Code der offiziellen Wrapper von Governikus übertragen.

**Ob eine App, die dieses Plugin und damit das SDK einbindet, selbst quelloffen sein muss, beantwortet dieses Dokument nicht.** Klären Sie diese Frage vor der Veröffentlichung Ihrer App mit Ihrer Rechtsabteilung und am besten direkt mit Governikus.
