/// A coarse classification of failures, for apps that show one text per
/// kind of failure and the raw code for everything else.
library;

/// What kind of failure a failure code stands for.
///
/// The raw code stays available where the kind is offered: `AuthResult.reason`,
/// `ChangePinCompleted.reason` and `AusweisAppException.code`.
///
/// The SDK codes are assigned by the list of failure codes in the SDK
/// documentation, `AusweisApp-community/docs/failurecodes/failurecodes.rst`
/// (included by `docs/sdk/failurecodes.rst`, SDK 2.6.3). A code that the
/// documentation does not clearly put into one of the kinds is [other].
enum FailureKind {
  /// A problem with the network connection. These are the codes for which
  /// the documentation recommends "Fix connection problems".
  ///
  /// The SDK has no code of its own for a device that is offline; that case
  /// arrives as one of these network errors.
  network,

  /// Something took too long: the SDK did not start or stop in time, the
  /// return address did not answer within 30 seconds, or the new PIN was not
  /// entered in time on a reader with a keypad.
  timeout,

  /// The user cancelled the workflow, or the app did with `cancel()`.
  userCancelled,

  /// The ID card was removed or the connection to it failed. These are
  /// `Card_Removed` and the codes for which the documentation recommends
  /// "Check ID card position".
  cardConnection,

  /// Every other failure, including codes this version does not know. Show
  /// the raw code, so that support can look it up.
  other;

  /// The kind of the SDK failure code [reason], as carried by
  /// `AuthResult.reason` and `ChangePinCompleted.reason`.
  ///
  /// Returns [other] for a code that is unknown or missing. The code is
  /// compared exactly as the SDK documents it.
  static FailureKind fromReason(String? reason) =>
      failureKindsByReason[reason] ?? other;
}

/// The SDK failure codes that have a kind of their own; all others are
/// [FailureKind.other].
///
/// Source: `AusweisApp-community/docs/failurecodes/failurecodes.rst`. The
/// test `test/failure_test.dart` compares this table with that file. Not
/// part of the public API; use [FailureKind.fromReason].
const Map<String, FailureKind> failureKindsByReason = {
  // "Possible Solutions: Fix connection problems".
  'Get_TcToken_Network_Error': FailureKind.network,
  'Generic_Send_Receive_Network_Error': FailureKind.network,
  'Check_Refresh_Address_Proxy_Error': FailureKind.network,
  'Check_Refresh_Address_Fatal_Tls_Error_After_Reply': FailureKind.network,
  'Check_Refresh_Address_Unknown_Network_Error': FailureKind.network,
  'Check_Refresh_Address_Fetch_Certificate_Error': FailureKind.network,
  'Generic_Provider_Communication_Network_Error': FailureKind.network,

  // "… did not provide an answer within 30 seconds."
  'Check_Refresh_Address_Service_Timeout': FailureKind.timeout,
  // "… the user took too long to set the new PIN."
  'Change_Pin_Input_Timeout': FailureKind.timeout,

  // "The user canceled the workflow." The two `Ifd` codes belong to a
  // smartphone used as a card reader.
  'User_Cancelled': FailureKind.userCancelled,
  'Establish_Pace_Channel_User_Cancelled': FailureKind.userCancelled,
  'Change_Pin_User_Cancelled': FailureKind.userCancelled,
  'Change_Pin_Card_User_Cancelled': FailureKind.userCancelled,
  'Enter_Pace_Password_Ifd_User_Cancelled': FailureKind.userCancelled,
  'Enter_New_Pace_Pin_Ifd_User_Cancelled': FailureKind.userCancelled,

  // `Card_Removed` and "Possible Solutions: Check ID card position". On an
  // iPhone, pulling the card away while it was read reported
  // `Transmit_Card_Command_Failed` and
  // `Did_Authenticate_Eac2_Card_Command_Failed`, not `Card_Removed`
  // (docs/device-test.md).
  'Card_Removed': FailureKind.cardConnection,
  'Connect_Card_Connection_Failed': FailureKind.cardConnection,
  'Maintain_Card_Connection_Pace_Unrecoverable': FailureKind.cardConnection,
  'Maintain_Card_Connection_Unknown_Error': FailureKind.cardConnection,
  'Did_Authenticate_Eac1_Card_Command_Failed': FailureKind.cardConnection,
  'Did_Authenticate_Eac2_Card_Command_Failed': FailureKind.cardConnection,
  'Transmit_Card_Command_Failed': FailureKind.cardConnection,
  'Change_Pin_Unexpected_Transmit_Status': FailureKind.cardConnection,
  'Change_Pin_Unrecoverable': FailureKind.cardConnection,
};
