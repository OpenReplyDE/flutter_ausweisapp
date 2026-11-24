// JSON examples copied unchanged from AusweisApp-community/docs/sdk/messages.rst.

const String accessRightsFull = r'''
{
  "msg": "ACCESS_RIGHTS",
  "error": "some optional error message",
  "chat":
        {
         "effective": ["Address", "FamilyName", "GivenNames", "AgeVerification", "CanAllowed"],
         "optional": ["GivenNames", "AgeVerification", "CanAllowed"],
         "required": ["Address", "FamilyName"]
        },
  "transactionInfo": "this is an example",
  "aux":
       {
        "ageVerificationDate": "1999-07-20",
        "requiredAge": "18",
        "validityDate": "2017-07-20",
        "communityId": "02760400110000"
       }
}
''';

const String accessRightsMinimal = r'''
{
  "msg": "ACCESS_RIGHTS",
  "chat":
        {
         "effective": ["Address", "FamilyName", "GivenNames", "AgeVerification"],
         "optional": ["GivenNames", "AgeVerification"],
         "required": ["Address", "FamilyName"]
        }
}
''';

const String apiLevel = r'''
{
  "msg": "API_LEVEL",
  "error": "optional error message like an invalid level",
  "available": [1,2,3],
  "current": 3
}
''';

const String authError = r'''
{
  "msg": "AUTH",
  "error": "error message if RUN_AUTH failed"
}
''';

const String authOk = r'''
{
  "msg": "AUTH",
  "result":
           {
            "major": "http://www.bsi.bund.de/ecard/api/1.1/resultmajor#ok"
           },
  "url": "https://test.governikus-eid.de/Autent-DemoApplication/refresh-address?sessionId=123456789&ResultMajor=ok"
}
''';

const String authFailed = r'''
{
  "msg": "AUTH",
  "result":
           {
            "major": "http://www.bsi.bund.de/ecard/api/1.1/resultmajor#error",
            "minor": "http://www.bsi.bund.de/ecard/api/1.1/resultminor/al/common#internalError",
            "language": "en",
            "description": "An internal error has occurred during processing.",
            "message": "The connection to the ID card has been lost. The process was aborted.",
            "reason": "Card_Removed"
           },
  "url": "https://test.governikus-eid.de/Autent-DemoApplication/refresh-address?sessionId=123456789&ResultMajor=error&ResultMinor=internalError"
}
''';

const String badState = r'''
{
  "msg": "BAD_STATE",
  "error": "NAME_OF_YOUR_COMMAND"
}
''';

const String certificate = r'''
{
  "msg": "CERTIFICATE",
  "description":
                {
                 "issuerName": "Governikus Test DVCA",
                 "issuerUrl": "http://www.governikus.de",
                 "subjectName": "Governikus Service GmbH",
                 "subjectUrl": "https://test.governikus-eid.de",
                 "termsOfUsage": "Anschrift:\t\r\nGovernikus Service GmbH\r\nAm Fallturm 9\r\n28359 Bremen\t\r\n\r\nE-Mail-Adresse:\thb@bos-bremen.de\t\r\n\r\nZweck des Auslesevorgangs:\tDemonstration des eID-Service\t\r\n\r\nZuständige Datenschutzaufsicht:\t\r\nDie Landesbeauftragte für Datenschutz und Informationsfreiheit der Freien Hansestadt Bremen\r\nArndtstraße 1\r\n27570 Bremerhaven",
                 "purpose": "Demonstration des eID-Service"
                },
  "validity":
             {
              "effectiveDate": "2016-07-31",
              "expirationDate": "2016-08-30"
             }
}
''';

const String changePinOk = r'''
{
  "msg": "CHANGE_PIN",
  "success": true
}
''';

const String changePinFailed = r'''
{
  "msg": "CHANGE_PIN",
  "success": false,
  "reason": "Card_Removed"
}
''';

const String enterCan = r'''
{
  "msg": "ENTER_CAN",
  "error": "You must provide 6 digits",
  "reader":
           {
            "name": "NFC",
            "insertable": false,
            "attached": true,
            "keypad": false,
            "card":
                   {
                    "inoperative": false,
                    "deactivated": false,
                    "retryCounter": 1
                   }
           }
}
''';

const String enterPin = r'''
{
  "msg": "ENTER_PIN",
  "error": "You must provide 6 digits",
  "reader":
           {
            "name": "NFC",
            "insertable": false,
            "attached": true,
            "keypad": false,
            "card":
                   {
                    "inoperative": false,
                    "deactivated": false,
                    "retryCounter": 3
                   }
           }
}
''';

const String enterNewPin = r'''
{
  "msg": "ENTER_NEW_PIN",
  "error": "You must provide 6 digits",
  "reader":
           {
            "name": "NFC",
            "insertable": false,
            "attached": true,
            "keypad": false,
            "card":
                   {
                    "inoperative": false,
                    "deactivated": false,
                    "retryCounter": 3
                   }
           }
}
''';

const String enterPuk = r'''
{
  "msg": "ENTER_PUK",
  "error": "You must provide 10 digits",
  "reader":
           {
            "name": "NFC",
            "insertable": false,
            "attached": true,
            "keypad": false,
            "card":
                   {
                    "inoperative": false,
                    "deactivated": false,
                    "retryCounter": 0
                   }
           }
}
''';

const String info = r'''
{
  "msg": "INFO",
  "VersionInfo":
                {
                 "Name": "AusweisApp2",
                 "Implementation-Title": "AusweisApp2",
                 "Implementation-Vendor": "Governikus Service GmbH",
                 "Implementation-Version": "2.0.0",
                 "Specification-Title": "TR-03124-1",
                 "Specification-Vendor": "Federal Office for Information Security",
                 "Specification-Version": "1.4"
                },
   "AusweisApp": "CONNECTED"
}
''';

const String insertCard = r'''
{
  "msg": "INSERT_CARD",
  "error": "Name cannot be undefined"
}
''';

const String internalError = r'''
{
  "msg": "INTERNAL_ERROR",
  "error": "Unexpected condition"
}
''';

const String invalid = r'''
{
  "msg": "INVALID",
  "error": "unterminated string (offset: 12)"
}
''';

const String readerEid = r'''
{
  "msg": "READER",
  "name": "NFC",
  "insertable": false,
  "attached": true,
  "keypad": false,
  "card":
         {
          "inoperative": false,
          "deactivated": false,
          "retryCounter": 3
         }
}
''';

const String readerUnknownCard = r'''
{
  "msg": "READER",
  "name": "NFC",
  "insertable": false,
  "attached": true,
  "keypad": false,
  "card": {}
}
''';

const String readerNoCard = r'''
{
  "msg": "READER",
  "name": "NFC",
  "insertable": false,
  "attached": true,
  "keypad": false,
  "card": null
}
''';

const String readerList = r'''
{
  "msg": "READER_LIST",
  "readers":
           [
             {
              "name": "Example reader 1 [SmartCard] (1234567) 01 00",
              "insertable": false,
              "attached": true,
              "keypad": true,
              "card": null
             },

             {
              "name": "NFC",
              "insertable": false,
              "attached": true,
              "keypad": false,
              "card":
                     {
                      "inoperative": false,
                      "deactivated": false,
                      "retryCounter": 3
                     }
             }
           ]
}
''';

const String status = r'''
{
  "msg": "STATUS",
  "workflow": "AUTH",
  "progress": 25,
  "state": "ACCESS_RIGHTS"
}
''';

const String pause = r'''
{
  "msg": "PAUSE",
  "cause": "BadCardPosition"
}
''';

const String unknownCommand = r'''
{
  "msg": "UNKNOWN_COMMAND",
  "error": "get_INFo"
}
''';
