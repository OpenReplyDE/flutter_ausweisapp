/// Data types carried by SDK messages.
library;

/// Information about an inserted card.
///
/// An empty `card` object in the protocol means an unknown card; all fields
/// are `null` then, see [isUnknown].
class Card {
  const Card({this.inoperative, this.deactivated, this.retryCounter});

  /// True if the PUK is inoperative and cannot unblock the PIN.
  final bool? inoperative;

  /// True if the eID function is deactivated.
  final bool? deactivated;

  /// Remaining PIN attempts.
  final int? retryCounter;

  /// Whether the SDK reported a card it could not identify.
  bool get isUnknown =>
      inoperative == null && deactivated == null && retryCounter == null;
}

/// A card reader, as reported by `READER` and `READER_LIST`.
class Reader {
  const Reader({
    required this.name,
    required this.insertable,
    required this.attached,
    this.keypad,
    this.card,
  });

  final String name;

  /// Whether a card can be inserted via `SET_CARD`.
  final bool insertable;

  /// Whether the reader is connected.
  final bool attached;

  /// Whether the reader has a keypad; only reported for attached readers.
  final bool? keypad;

  /// The inserted card, or `null` if there is none.
  final Card? card;
}

/// Auxiliary data of the service provider.
class AuxiliaryData {
  const AuxiliaryData({
    this.ageVerificationDate,
    this.requiredAge,
    this.validityDate,
    this.communityId,
  });

  final DateTime? ageVerificationDate;
  final int? requiredAge;
  final DateTime? validityDate;
  final String? communityId;
}

/// Access rights requested by the service provider.
class AccessRights {
  const AccessRights({
    required this.effective,
    required this.optional,
    required this.required,
    this.transactionInfo,
    this.aux,
  });

  /// Enabled rights out of [optional] and [required].
  final List<String> effective;

  /// Rights the user may disable.
  final List<String> optional;

  /// Rights that cannot be disabled.
  final List<String> required;

  final String? transactionInfo;
  final AuxiliaryData? aux;
}

/// Final result of an authentication.
class AuthResult {
  const AuthResult({
    this.major,
    this.minor,
    this.language,
    this.description,
    this.message,
    this.reason,
    this.url,
  });

  final String? major;
  final String? minor;
  final String? language;
  final String? description;
  final String? message;

  /// Unique failure code.
  final String? reason;

  /// Refresh URL or communication error address.
  final Uri? url;

  /// Whether the authentication succeeded (`major` ends with `#ok`).
  bool get isSuccess => major != null && major!.endsWith('#ok');
}

/// The certificate of the service provider.
class Certificate {
  const Certificate({
    this.issuerName,
    this.issuerUrl,
    this.subjectName,
    this.subjectUrl,
    this.termsOfUsage,
    this.purpose,
    this.effectiveDate,
    this.expirationDate,
  });

  final String? issuerName;
  final String? issuerUrl;
  final String? subjectName;
  final String? subjectUrl;
  final String? termsOfUsage;
  final String? purpose;
  final DateTime? effectiveDate;
  final DateTime? expirationDate;
}

/// Version information of the AusweisApp.
class VersionInfo {
  const VersionInfo({
    this.name,
    this.implementationTitle,
    this.implementationVendor,
    this.implementationVersion,
    this.specificationTitle,
    this.specificationVendor,
    this.specificationVersion,
  });

  final String? name;
  final String? implementationTitle;
  final String? implementationVendor;
  final String? implementationVersion;
  final String? specificationTitle;
  final String? specificationVendor;
  final String? specificationVersion;
}

/// Names of the access rights known to the SDK.
abstract final class AccessRight {
  static const address = 'Address';
  static const birthName = 'BirthName';
  static const familyName = 'FamilyName';
  static const givenNames = 'GivenNames';
  static const placeOfBirth = 'PlaceOfBirth';
  static const dateOfBirth = 'DateOfBirth';
  static const doctoralDegree = 'DoctoralDegree';
  static const artisticName = 'ArtisticName';
  static const pseudonym = 'Pseudonym';
  static const validUntil = 'ValidUntil';
  static const nationality = 'Nationality';
  static const issuingCountry = 'IssuingCountry';
  static const documentType = 'DocumentType';
  static const residencePermitI = 'ResidencePermitI';
  static const residencePermitII = 'ResidencePermitII';
  static const communityId = 'CommunityID';
  static const addressVerification = 'AddressVerification';
  static const ageVerification = 'AgeVerification';
  static const writeAddress = 'WriteAddress';
  static const writeCommunityId = 'WriteCommunityID';
  static const writeResidencePermitI = 'WriteResidencePermitI';
  static const writeResidencePermitII = 'WriteResidencePermitII';
  static const canAllowed = 'CanAllowed';
  static const pinManagement = 'PinManagement';
}

/// Causes reported by the `PAUSE` message.
abstract final class PauseCause {
  static const badCardPosition = 'BadCardPosition';
}
