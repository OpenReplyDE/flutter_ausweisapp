import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ausweisapp/flutter_ausweisapp.dart';

import 'web_login.dart';

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

/// Root of the example app. In tests, [transport] replaces the native
/// transport, [nfc] the NFC state of the device and [webLogin] the web view.
class MyApp extends StatelessWidget {
  const MyApp({super.key, this.transport, this.nfc, this.webLogin});

  final AusweisAppTransport? transport;
  final AusweisAppNfc? nfc;
  final WebLogin Function()? webLogin;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_ausweisapp example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: TestScreen(transport: transport, nfc: nfc, webLogin: webLogin),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key, this.transport, this.nfc, this.webLogin});

  final AusweisAppTransport? transport;
  final AusweisAppNfc? nfc;
  final WebLogin Function()? webLogin;

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> with WidgetsBindingObserver {
  late final AusweisApp _eid;
  late final AusweisAppNfc _nfc;
  late final StreamSubscription<AusweisAppEvent> _subscription;
  final _urlController = TextEditingController(text: _defaultTcTokenUrl);
  final _linkController = TextEditingController();
  final _loginUrlController = TextEditingController();
  final _secretController = TextEditingController();
  final List<String> _log = [];

  bool _developerMode = true;
  bool _pluginLogging = false;
  bool _autoInterrupt = true;

  /// The last answer of the device; null before the first answer and after
  /// a failed query.
  NfcStatus? _nfcStatus;
  String? _linkHint;
  List<String> _optionalRights = const [];
  Set<String> _enabledRights = {};

  /// The browser session of the web login, created on first use.
  WebLogin? _web;
  bool _webPageOpen = false;

  /// True while an authentication runs that the web page asked for; its
  /// return address then goes back into the browser session.
  bool _webLoginPending = false;

  /// The scheme of `redirect_uri` in the login address, if it names one.
  String? _redirectScheme;

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
    // The NFC state needs no running SDK. It has no change notifications, so
    // the app asks again whenever it comes back to the foreground, for
    // example from the NFC settings.
    _nfc = widget.nfc ?? const MethodChannelAusweisAppNfc();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshNfcStatus());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshNfcStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    _eid.dispose();
    _urlController.dispose();
    _linkController.dispose();
    _loginUrlController.dispose();
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
    _addLog('Ereignis: ${_describe(event)}');
    if (event case AuthenticationCompleted(:final result)) {
      _finishWebLogin(result);
    }
    // By the SDK documentation, the iOS NFC dialog stays open after the SDK
    // asks for input; INTERRUPT closes it so that the input can be made.
    final asksForInput = switch (event) {
      PinRequested() ||
      CanRequested() ||
      PukRequested() ||
      NewPinRequested() => true,
      _ => false,
    };
    if (asksForInput && _autoInterrupt && _isIos) {
      _run('INTERRUPT (automatisch)', _eid.interrupt);
    }
  }

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

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

  /// Asks the device for its NFC state. [log] also writes the answer to the
  /// log; the automatic queries only update the status line.
  Future<void> _refreshNfcStatus({bool log = false}) async {
    NfcStatus? status;
    try {
      status = await _nfc.status();
    } on AusweisAppException catch (e) {
      _addLog('Fehler bei NFC-Status: $e');
    } on Object catch (e) {
      _addLog('Unerwarteter Fehler bei NFC-Status: ${e.runtimeType}');
    }
    if (!mounted) return;
    setState(() => _nfcStatus = status);
    if (log && status != null) {
      _addLog('NFC-Status: ${_nfcLabel(status)} (${status.name})');
    }
  }

  /// Opens the NFC settings of the system. On iOS there are none; the log
  /// then says that nothing was opened.
  Future<void> _openNfcSettings() async {
    try {
      final opened = await _nfc.openSettings();
      _addLog('NFC-Einstellungen geöffnet: ${opened ? 'ja' : 'nein'}');
    } on AusweisAppException catch (e) {
      _addLog('Fehler bei NFC-Einstellungen: $e');
    } on Object catch (e) {
      _addLog('Unerwarteter Fehler bei NFC-Einstellungen: ${e.runtimeType}');
    }
  }

  static String _nfcLabel(NfcStatus? status) => switch (status) {
    NfcStatus.unsupported => 'kein NFC',
    NfcStatus.disabled => 'ausgeschaltet',
    NfcStatus.available => 'verfügbar',
    null => 'unbekannt',
  };

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

  /// Opens the login address in the browser session of the example app.
  void _openWebLogin() {
    final url = Uri.tryParse(_loginUrlController.text.trim());
    if (url == null || !url.isAbsolute || url.host.isEmpty) {
      _addLog('Ungültige Login-Adresse: bitte eine absolute Adresse angeben.');
      return;
    }
    final web = _web ??= (widget.webLogin ?? WebViewLogin.new)();
    web.onNavigation = _onWebNavigation;
    final redirect = Uri.tryParse(url.queryParameters['redirect_uri'] ?? '');
    _redirectScheme = redirect?.scheme;
    unawaited(web.load(url));
    _showWebPage();
  }

  void _showWebPage() {
    final web = _web;
    if (web == null || _webPageOpen) return;
    _webPageOpen = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Anmeldung im Browser')),
              body: web.buildView(),
            ),
          ),
        )
        .whenComplete(() => _webPageOpen = false);
  }

  /// Takes an eID client link over from the web page: closes the page and
  /// starts the authentication with the tcTokenURL of the link. Addresses
  /// are not logged, because they carry session tokens.
  bool _onWebNavigation(Uri url) {
    final tcTokenUrl = tcTokenUrlFromEidClientLink(url);
    if (tcTokenUrl == null) return _onAppRedirect(url);
    if (_webPageOpen) Navigator.of(context).pop();
    _urlController.text = tcTokenUrl.toString();
    _webLoginPending = true;
    _addLog('eID-Client-Link aus dem Browser übernommen.');
    unawaited(_startAuthenticationFromWeb());
    return true;
  }

  /// Schemes that a web page opens itself. Everything else is a redirect to
  /// an app, which a web view cannot follow.
  static const _webSchemes = {'http', 'https', 'about', 'data', 'blob'};

  /// A login ends in a redirect to the scheme of the app that asked for it
  /// (for example `de.example.app:/oauth2redirect?code=…`), which the login
  /// address names in `redirect_uri`. Before that, a page may link to
  /// another app, as ELSTER does with ElsterSecure; such a link goes to
  /// that app, and the web page stays open for the way back.
  bool _onAppRedirect(Uri url) {
    if (_webSchemes.contains(url.scheme)) return false;
    if (url.scheme == _redirectScheme) {
      _reportAppRedirect(url);
    } else {
      unawaited(_openInApp(url));
    }
    return true;
  }

  Future<void> _openInApp(Uri url) async {
    final opened = await _web?.openInApp(url) ?? false;
    if (!mounted) return;
    if (!opened) return _reportAppRedirect(url);
    _addLog('Link an eine andere App übergeben (${_schemeAndNames(url)}).');
  }

  /// The example only reports the redirect to the app that asked for the
  /// login: it closes the web page and logs the scheme and the names of the
  /// parameters, never their values.
  void _reportAppRedirect(Uri url) {
    if (_webPageOpen) Navigator.of(context).pop();
    _addLog('Weiterleitung an eine App empfangen (${_schemeAndNames(url)}).');
  }

  static String _schemeAndNames(Uri url) {
    final names = url.queryParameters.keys.toList()..sort();
    return 'Schema: ${url.scheme}, Parameter: ${names.join(', ')}';
  }

  Future<void> _startAuthenticationFromWeb() async {
    if (!_eid.isRunning) await _run('Start', _eid.start);
    if (!mounted) return;
    // A login in the browser belongs to a real service, and the SDK refuses
    // a real service in developer mode. The switch is for the test service.
    _startAuthentication(developerMode: false);
  }

  /// Opens the return address of an authentication that the web page asked
  /// for in the same browser session, so that the service can finish the
  /// login there.
  ///
  /// After a failed authentication the app stays on the log, so that the
  /// reason remains visible, and leaves the return address unopened.
  void _finishWebLogin(AuthResult result) {
    if (!_webLoginPending) return;
    _webLoginPending = false;
    final web = _web;
    final returnUrl = result.url;
    if (web == null || returnUrl == null) return;
    if (!result.isSuccess) {
      _addLog(
        'Authentisierung gescheitert: Die Rückkehr-Adresse wurde nicht '
        'geöffnet, der Grund steht in der Zeile darunter.',
      );
      return;
    }
    unawaited(web.load(returnUrl));
    _addLog('Rückkehr-Adresse im Browser geöffnet.');
    _showWebPage();
  }

  /// Starts the authentication with the address in the tcTokenURL field.
  /// [developerMode] defaults to the switch.
  void _startAuthentication({bool? developerMode}) {
    final url = Uri.tryParse(_urlController.text.trim());
    if (url == null || !url.isAbsolute || url.host.isEmpty) {
      _addLog('Ungültige tcTokenURL: bitte eine absolute Adresse angeben.');
      return;
    }
    _run(
      'RUN_AUTH',
      () => _eid.startAuthentication(
        tcTokenUrl: url,
        developerMode: developerMode ?? _developerMode,
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
          _buildNfcSection(),
          _buildWebLoginSection(),
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

  Widget _buildNfcSection() {
    return _section('NFC', [
      Text('NFC: ${_nfcLabel(_nfcStatus)}'),
      _wrap([
        FilledButton.tonal(
          onPressed: () => _refreshNfcStatus(log: true),
          child: const Text('NFC-Status abfragen'),
        ),
        FilledButton.tonal(
          onPressed: _openNfcSettings,
          child: const Text('Zu den NFC-Einstellungen'),
        ),
      ]),
    ]);
  }

  Widget _buildWebLoginSection() {
    return _section('Anmeldung im Browser', [
      TextField(
        key: const Key('loginUrlField'),
        controller: _loginUrlController,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Login-Adresse',
          helperText:
              'Öffnet den Login eines Dienstes. Der eID-Client-Link der '
              'Seite startet die Authentisierung, immer ohne '
              'Entwicklermodus.',
          helperMaxLines: 4,
        ),
      ),
      const SizedBox(height: 8),
      _wrap([
        FilledButton.tonal(
          onPressed: _openWebLogin,
          child: const Text('Im Browser anmelden'),
        ),
      ]),
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
      if (_isIos)
        SwitchListTile(
          key: const Key('autoInterruptSwitch'),
          title: const Text(
            'NFC-Dialog bei PIN-, CAN- und PUK-Abfrage automatisch schließen',
          ),
          subtitle: const Text(
            'Sendet INTERRUPT, sobald das SDK eine Eingabe verlangt.',
          ),
          value: _autoInterrupt,
          onChanged: (v) => setState(() => _autoInterrupt = v),
        ),
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

/// The name of [event] and its main fields, for the log.
///
/// Fields of the SDK keep their API names (`error`, `retryCounter`, …), so
/// that they are not mistaken for the app's own `Fehler:` lines. No event
/// carries a PIN, CAN or PUK. URLs are left out because they can carry a
/// session token; the log only says whether one is present.
String _describe(AusweisAppEvent event) {
  List<String> reader(Reader reader) => [
    'Leser: ${reader.name}',
    'Karte: ${reader.card == null ? 'nein' : 'ja'}',
    if (reader.card?.retryCounter case final counter?) 'retryCounter: $counter',
  ];
  List<String> error(String? text) => [if (text != null) 'error: $text'];

  final fields = switch (event) {
    AuthenticationStarted() ||
    ChangePinStarted() ||
    UnknownMessageReceived() ||
    Disconnected() => const <String>[],
    AuthenticationStartFailed(error: final text) => error(text),
    AuthenticationCompleted(:final result) => [
      'isSuccess: ${result.isSuccess}',
      if (result.major != null) 'major: ${result.major}',
      if (result.minor != null) 'minor: ${result.minor}',
      if (result.reason != null) 'reason: ${result.reason}',
      if (result.failureKind case final kind?) 'failureKind: ${kind.name}',
      'URL: ${result.url == null ? 'keine' : 'vorhanden'}',
    ],
    AccessRightsRequested(error: final text) => error(text),
    InsertCardRequested(error: final text) => error(text),
    PinRequested(reader: final r, error: final text) ||
    CanRequested(reader: final r, error: final text) ||
    PukRequested(reader: final r, error: final text) ||
    NewPinRequested(
      reader: final r,
      error: final text,
    ) => [...reader(r), ...error(text)],
    Paused(:final cause) => ['cause: $cause'],
    ChangePinCompleted(:final success, :final reason, :final failureKind) => [
      'success: $success',
      if (reason != null) 'reason: $reason',
      if (failureKind != null) 'failureKind: ${failureKind.name}',
    ],
    CertificateReceived(:final certificate) => [
      if (certificate.subjectName != null)
        'subjectName: ${certificate.subjectName}',
    ],
    ReaderChanged(reader: final r) => reader(r),
    ReaderListReceived(:final readers) => [
      if (readers.isEmpty)
        'Leser: keine'
      else
        'Leser: ${readers.map((r) => r.name).join(', ')}',
    ],
    StatusChanged(:final workflow, :final progress, :final state) => [
      'workflow: $workflow',
      'progress: $progress',
      'state: $state',
    ],
    InfoReceived(:final versionInfo, :final ausweisApp) => [
      'Version: ${versionInfo?.implementationVersion}',
      if (ausweisApp != null) 'ausweisApp: $ausweisApp',
    ],
    ApiLevelReceived(:final current, :final available, error: final text) => [
      'current: $current',
      'available: ${available.join(', ')}',
      ...error(text),
    ],
    BadState(:final command) ||
    UnknownCommand(:final command) => ['command: $command'],
    InternalError(error: final text) ||
    InvalidCommand(error: final text) => error(text),
  };
  final name = event.runtimeType.toString();
  return fields.isEmpty ? name : '$name (${fields.join(', ')})';
}
