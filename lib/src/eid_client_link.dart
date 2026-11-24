/// Reading the token URL from an eID client link.
library;

/// Returns the `tcTokenURL` carried by an eID client [link], or `null`.
///
/// A link such as `http://127.0.0.1:24727/eID-Client?tcTokenURL=<encoded URL>`
/// yields the decoded inner URL. Returns `null` when the path is not exactly
/// `/eID-Client` (case-sensitive), when the parameter is missing or empty,
/// when it does not parse, or when it is not an absolute `https` address with
/// a non-empty host. Never throws, also not for malformed percent-encoding.
Uri? tcTokenUrlFromEidClientLink(Uri link) {
  if (link.path != '/eID-Client') {
    return null;
  }
  final String? raw;
  try {
    raw = link.queryParameters['tcTokenURL'];
  } on FormatException {
    return null;
  }
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final token = Uri.tryParse(raw);
  if (token == null || token.scheme != 'https' || token.host.isEmpty) {
    return null;
  }
  return token;
}
