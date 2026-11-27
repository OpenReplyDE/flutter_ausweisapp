import 'package:flutter_ausweisapp_example/web_login.dart';
import 'package:flutter_test/flutter_test.dart';

const _webKit = 'AppleWebKit/605.1.15 (KHTML, like Gecko)';
const _iPhone = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X)';
const _iPad = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)';
const _android =
    'Mozilla/5.0 (Linux; Android 15; Pixel 8 Build/AP3A.241005.015; wv) '
    'AppleWebKit/537.36 (KHTML, like Gecko)';

void main() {
  test('an iPhone web view gets the Safari tokens with the system version', () {
    expect(
      browserUserAgent(
        '$_iPhone $_webKit Mobile/15E148',
        osVersion: 'Version 27.2.1 (Build 24B156)',
      ),
      '$_iPhone $_webKit Version/27.2 Mobile/15E148 Safari/604.1',
    );
  });

  test('an iPad web view without a Mobile token gets the Safari tokens', () {
    expect(
      browserUserAgent('$_iPad $_webKit', osVersion: 'Version 27.2'),
      '$_iPad $_webKit Version/27.2 Safari/604.1',
    );
  });

  test('an Android web view loses the Version token of the web view', () {
    expect(
      browserUserAgent(
        '$_android Version/4.0 Chrome/131.0.6778.135 Mobile Safari/537.36',
        osVersion: '15',
      ),
      '$_android Chrome/131.0.6778.135 Mobile Safari/537.36',
    );
  });

  test('a user agent that already names Safari stays unchanged', () {
    const safari = '$_iPhone $_webKit Version/26.0 Mobile/15E148 Safari/604.1';

    expect(browserUserAgent(safari, osVersion: 'Version 27.2.1'), safari);
  });

  test('an iPhone web view stays unchanged without a system version', () {
    const webView = '$_iPhone $_webKit Mobile/15E148';

    expect(browserUserAgent(webView, osVersion: 'unknown'), webView);
  });
}
