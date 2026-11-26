# License notice

Deutsche Fassung: [NOTICE.de.md](NOTICE.de.md)

This notice is addressed to everyone who uses or redistributes the plugin `flutter_ausweisapp` or ships an app with it, and to their legal department. It is not legal advice.

## The plugin is licensed under the EUPL 1.2

Copyright © 2026 Open Reply GmbH.

The plugin is open source and is licensed under the European Union Public Licence (EUPL), version 1.2. The full license text is in the file `LICENSE` in this repository.

The EUPL contains a copyleft clause: whoever redistributes the plugin or a modification of it must comply with the conditions of Article 5 of the EUPL. These include redistribution under the EUPL and making the source code available.

## The SDK is also licensed under the EUPL 1.2

The plugin integrates the Governikus AusweisApp SDK, version 2.6.3, as a prebuilt Android package (`com.governikus:ausweisapp`) and as an iOS Swift package (`https://github.com/Governikus/AusweisApp2-SDK-iOS`). The SDK is not part of this repository; the build tools download it when the app is built. The source code of the SDK is licensed under the EUPL 1.2.

Whoever ships an app with this plugin thereby distributes a copy of the SDK. The obligations under Article 5 of the EUPL apply to this. The app must therefore:

1. include the SDK's copyright and license notices,
2. include the license text,
3. refer to the SDK's source code: `https://github.com/Governikus/AusweisApp`.

The license terms that Governikus includes with the SDK are in this repository at `AusweisApp-community/LICENSE.txt`. In the same folder, under `AusweisApp-community/docs/sdk/`, is the SDK's protocol documentation, which the plugin was written against; it comes from the Governikus repository and is also licensed under the EUPL 1.2.

## Additional agreements on the AusweisApp

The iOS binary package comes with a version that contains "Zusatzvereinbarungen zur AusweisApp" (additional agreements on the AusweisApp) in addition to the EUPL. It is in this repository at `AusweisApp-community/LICENSE.officially.txt`, Section B. Under Paragraph 3, the AusweisApp and all its components serve exclusively the online ID function, and under Paragraph 6, the marks "AusweisApp" and the associated graphics are protected as trademarks of the German federal government. Paragraph 1, subparagraph 3 states that the additional agreements leave the rights and obligations under the EUPL unaffected. Read the section in full before you ship an app.

## What remains open for your app

The copyleft clause of the EUPL applies to copies and modifications. When your own code counts as a modification is expressly left open by the EUPL, which refers to the applicable copyright law.

The plugin does not modify the SDK and addresses it only through the documented JSON interface. It was designed according to the SDK's protocol documentation and was not carried over from the code of the official Governikus wrappers.

**Whether an app that integrates this plugin, and with it the SDK, must itself be open source is not answered by this document.** Clarify this question with your legal department before publishing your app, ideally directly with Governikus.
