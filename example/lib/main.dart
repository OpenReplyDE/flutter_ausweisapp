import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';

void main() => runApp(const MyApp());

const _defaultTcTokenUrl =
    'https://test.governikus-eid.de/Autent-DemoApplication/api/eid/request';

/// Fixed texts of the iOS NFC dialog.
const _nfcMessages = UserInfoMessages(
  sessionStarted: 'Bitte halten Sie den Ausweis an das Gerät.',
  sessionFailed: 'Der Ausweis konnte nicht gelesen werden.',
  sessionSucceeded: 'Der Ausweis wurde gelesen.',
  sessionInProgress: 'Ausweis wird gelesen. Nicht bewegen.',
);

/// Root of the example app. [transport] replaces the native one in tests.
class MyApp extends StatelessWidget {
  const MyApp({super.key, this.transport});

  final AusweisAppTransport? transport;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_ausweisapp example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: TestScreen(transport: transport),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key, this.transport});

  final AusweisAppTransport? transport;

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  late final AusweisApp _eid;
  late final StreamSubscription<AusweisAppEvent> _subscription;
  final _urlController = TextEditingController(text: _defaultTcTokenUrl);
  final _linkController = TextEditingController();
  final _secretController = TextEditingController();
  final List<String> _log = [];

  bool _developerMode = true;
  bool _pluginLogging = false;
  String? _linkHint;
  List<String> _optionalRights = const [];
  Set<String> _enabledRights = {};

  @override
  void initState() {
    super.initState();
    _eid = AusweisApp(
      transport: widget.transport,
      logger: (line) {
        if (_pluginLogging) _addLog('[Plugin] $line');
      },
    );
    // Subscribe before start() so that no event is missed.
    _subscription = _eid.events.listen(_onEvent, onError: _onError);
  }

  @override
  void dispose() {
    _subscription.cancel();
    _eid.dispose();
    _urlController.dispose();
    _linkController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _addLog(String line) {
    if (!mounted) return;
    setState(() => _log.insert(0, line));
  }

  void _onError(Object error) => _addLog('Fehler: $error');

  void _onEvent(AusweisAppEvent event) {
    switch (event) {
      case AccessRightsRequested(:final rights):
        setState(() {
          _optionalRights = rights.optional;
          _enabledRights = rights.effective.toSet();
        });
      case Disconnected():
        setState(() {});
      default:
    }
    _addLog('Ereignis: ${event.runtimeType}');
  }

  /// Runs [action]; a plugin error goes to the log instead of the zone.
  Future<void> _run(String name, Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      setState(() {});
      if (name.isNotEmpty) _addLog('Gesendet: $name');
    } on AusweisAppException catch (e) {
      _addLog('Fehler bei $name: $e');
    } on Object catch (e) {
      // Only the type: the message of an unexpected error could carry input.
      _addLog('Unerwarteter Fehler bei $name: ${e.runtimeType}');
    }
  }

  void _useClientLink() {
    final link = Uri.tryParse(_linkController.text.trim());
    final url = link == null ? null : tcTokenUrlFromEidClientLink(link);
    setState(() {
      if (url == null) {
        _linkHint =
            'Kein gültiger eID-Client-Link (erwartet: …/eID-Client?tcTokenURL=https://…).';
      } else {
        _linkHint = null;
        _urlController.text = url.toString();
      }
    });
  }

  void _startAuthentication() {
    final url = Uri.tryParse(_urlController.text.trim());
    if (url == null || !url.isAbsolute || url.host.isEmpty) {
      _addLog('Ungültige tcTokenURL: bitte eine absolute Adresse angeben.');
      return;
    }
    _run(
      'RUN_AUTH',
      () => _eid.startAuthentication(
        tcTokenUrl: url,
        developerMode: _developerMode,
        userInfoMessages: _nfcMessages,
      ),
    );
  }

  void _setRight(String right, bool on) {
    setState(
      () => on ? _enabledRights.add(right) : _enabledRights.remove(right),
    );
    final chosen = _optionalRights.where(_enabledRights.contains).toList();
    _run('SET_ACCESS_RIGHTS', () => _eid.setAccessRights(chosen));
  }

  /// Sends the entered secret. The value is never written to the log.
  /// An empty field sends the command without a value, as readers with a
  /// keypad (such as the simulator) require.
  void _sendSecret(String name, Future<void> Function(String? value) send) {
    final value = _secretController.text;
    _run(name, () => send(value.isEmpty ? null : value));
  }

  Widget _button(String label, Future<void> Function() action, {String? name}) {
    return FilledButton.tonal(
      onPressed: () => _run(name ?? label, action),
      child: Text(label),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _wrap(List<Widget> children) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AusweisApp Testoberfläche')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSdkSection(),
          _buildAuthSection(),
          _buildSecretSection(),
          _buildCommandSection(),
          if (_optionalRights.isNotEmpty) _buildRightsSection(),
          _buildLogSection(),
        ],
      ),
    );
  }

  Widget _buildSdkSection() {
    return _section('SDK', [
      Text(_eid.isRunning ? 'SDK läuft' : 'SDK gestoppt'),
      _wrap([
        FilledButton(
          onPressed: () => _run('Start', _eid.start),
          child: const Text('SDK starten'),
        ),
        _button('SDK stoppen', _eid.stop),
      ]),
      SwitchListTile(
        key: const Key('pluginLogSwitch'),
        title: const Text('Plugin-Protokoll mitschreiben'),
        value: _pluginLogging,
        onChanged: (v) => setState(() => _pluginLogging = v),
      ),
    ]);
  }

  Widget _buildAuthSection() {
    return _section('Authentisierung', [
      TextField(
        key: const Key('tcTokenUrlField'),
        controller: _urlController,
        decoration: const InputDecoration(labelText: 'tcTokenURL'),
      ),
      SwitchListTile(
        title: const Text('Entwicklermodus'),
        value: _developerMode,
        onChanged: (v) => setState(() => _developerMode = v),
      ),
      TextField(
        key: const Key('clientLinkField'),
        controller: _linkController,
        decoration: InputDecoration(
          labelText: 'eID-Client-Link',
          errorText: _linkHint,
          errorMaxLines: 3,
        ),
      ),
      const SizedBox(height: 8),
      _wrap([
        OutlinedButton(
          onPressed: _useClientLink,
          child: const Text('Link übernehmen'),
        ),
        FilledButton.tonal(
          onPressed: _startAuthentication,
          child: const Text('Authentisierung starten'),
        ),
        _button(
          'PIN-Änderung starten',
          () => _eid.startChangePin(userInfoMessages: _nfcMessages),
          name: 'RUN_CHANGE_PIN',
        ),
      ]),
    ]);
  }

  Widget _buildSecretSection() {
    return _section('PIN, CAN, PUK', [
      TextField(
        key: const Key('secretField'),
        controller: _secretController,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Eingabe',
          helperText:
              'Leer lassen bei Kartenlesern mit eigener Tastatur '
              '(Simulator-Karte)',
          helperMaxLines: 2,
        ),
      ),
      const SizedBox(height: 8),
      _wrap([
        OutlinedButton(
          onPressed: () => _sendSecret('SET_PIN', _eid.setPin),
          child: const Text('als PIN senden'),
        ),
        OutlinedButton(
          onPressed: () => _sendSecret('SET_CAN', _eid.setCan),
          child: const Text('als CAN senden'),
        ),
        OutlinedButton(
          onPressed: () => _sendSecret('SET_PUK', _eid.setPuk),
          child: const Text('als PUK senden'),
        ),
        OutlinedButton(
          onPressed: () => _sendSecret('SET_NEW_PIN', _eid.setNewPin),
          child: const Text('als neue PIN senden'),
        ),
      ]),
    ]);
  }

  Widget _buildCommandSection() {
    return _section('Befehle', [
      _wrap([
        _button('Akzeptieren', _eid.accept, name: 'ACCEPT'),
        _button('Abbrechen', _eid.cancel, name: 'CANCEL'),
        _button('Fortsetzen', _eid.continueWorkflow, name: 'CONTINUE'),
        _button('Unterbrechen', _eid.interrupt, name: 'INTERRUPT'),
        _button('Zertifikat', _eid.getCertificate, name: 'GET_CERTIFICATE'),
        _button(
          'Zugriffsrechte',
          _eid.getAccessRights,
          name: 'GET_ACCESS_RIGHTS',
        ),
        _button('Info', _eid.getInfo, name: 'GET_INFO'),
        _button('Status', _eid.getStatus, name: 'GET_STATUS'),
        _button('Leserliste', _eid.getReaderList, name: 'GET_READER_LIST'),
        _button(
          'Simulator-Karte einlegen',
          () => _eid.setCard('Simulator'),
          name: 'SET_CARD',
        ),
      ]),
    ]);
  }

  Widget _buildRightsSection() {
    return _section('Optionale Zugriffsrechte', [
      for (final right in _optionalRights)
        SwitchListTile(
          title: Text(right),
          value: _enabledRights.contains(right),
          onChanged: (on) => _setRight(right, on),
        ),
    ]);
  }

  Widget _buildLogSection() {
    return _section('Protokoll', [
      Column(
        key: const Key('eventLog'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final line in _log) Text(line)],
      ),
    ]);
  }
}
