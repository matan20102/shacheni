import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @appName.
  ///
  /// In he, this message translates to:
  /// **'שכני'**
  String get appName;

  /// No description provided for @cancel.
  ///
  /// In he, this message translates to:
  /// **'ביטול'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In he, this message translates to:
  /// **'אישור'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In he, this message translates to:
  /// **'שמירה'**
  String get save;

  /// No description provided for @continueLabel.
  ///
  /// In he, this message translates to:
  /// **'המשך'**
  String get continueLabel;

  /// No description provided for @back.
  ///
  /// In he, this message translates to:
  /// **'חזרה'**
  String get back;

  /// No description provided for @close.
  ///
  /// In he, this message translates to:
  /// **'סגירה'**
  String get close;

  /// No description provided for @done.
  ///
  /// In he, this message translates to:
  /// **'סיום'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In he, this message translates to:
  /// **'נסו שוב'**
  String get retry;

  /// No description provided for @seeAll.
  ///
  /// In he, this message translates to:
  /// **'הכול'**
  String get seeAll;

  /// No description provided for @send.
  ///
  /// In he, this message translates to:
  /// **'שליחה'**
  String get send;

  /// No description provided for @submit.
  ///
  /// In he, this message translates to:
  /// **'שליחה'**
  String get submit;

  /// No description provided for @edit.
  ///
  /// In he, this message translates to:
  /// **'עריכה'**
  String get edit;

  /// No description provided for @yes.
  ///
  /// In he, this message translates to:
  /// **'כן'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In he, this message translates to:
  /// **'לא'**
  String get no;

  /// No description provided for @optional.
  ///
  /// In he, this message translates to:
  /// **'אופציונלי'**
  String get optional;

  /// No description provided for @today.
  ///
  /// In he, this message translates to:
  /// **'היום'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In he, this message translates to:
  /// **'מחר'**
  String get tomorrow;

  /// No description provided for @now.
  ///
  /// In he, this message translates to:
  /// **'עכשיו'**
  String get now;

  /// No description provided for @free.
  ///
  /// In he, this message translates to:
  /// **'חינם'**
  String get free;

  /// No description provided for @accept.
  ///
  /// In he, this message translates to:
  /// **'אישור'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In he, this message translates to:
  /// **'דחייה'**
  String get decline;

  /// No description provided for @approve.
  ///
  /// In he, this message translates to:
  /// **'אישור'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In he, this message translates to:
  /// **'דחייה'**
  String get reject;

  /// No description provided for @loadError.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו לטעון'**
  String get loadError;

  /// No description provided for @copy.
  ///
  /// In he, this message translates to:
  /// **'העתקה'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In he, this message translates to:
  /// **'הועתק'**
  String get copied;

  /// No description provided for @call.
  ///
  /// In he, this message translates to:
  /// **'התקשרות'**
  String get call;

  /// No description provided for @whatsapp.
  ///
  /// In he, this message translates to:
  /// **'וואטסאפ'**
  String get whatsapp;

  /// No description provided for @youLabel.
  ///
  /// In he, this message translates to:
  /// **'אתם'**
  String get youLabel;

  /// No description provided for @verifiedResident.
  ///
  /// In he, this message translates to:
  /// **'תושב/ת מאומת/ת של {building}'**
  String verifiedResident(String building);

  /// No description provided for @newNeighbor.
  ///
  /// In he, this message translates to:
  /// **'שכן/ה חדש/ה'**
  String get newNeighbor;

  /// No description provided for @completedCount.
  ///
  /// In he, this message translates to:
  /// **'{n} עסקאות הושלמו'**
  String completedCount(String n);

  /// No description provided for @memberSince.
  ///
  /// In he, this message translates to:
  /// **'חבר/ה מאז {year}'**
  String memberSince(String year);

  /// No description provided for @inHM.
  ///
  /// In he, this message translates to:
  /// **'בעוד {h} שע׳ {m} דק׳'**
  String inHM(String h, String m);

  /// No description provided for @inM.
  ///
  /// In he, this message translates to:
  /// **'בעוד {m} דק׳'**
  String inM(String m);

  /// No description provided for @overdue.
  ///
  /// In he, this message translates to:
  /// **'עבר הזמן'**
  String get overdue;

  /// No description provided for @untilTime.
  ///
  /// In he, this message translates to:
  /// **'עד {time}'**
  String untilTime(String time);

  /// No description provided for @dayAtTime.
  ///
  /// In he, this message translates to:
  /// **'{day}, {time}'**
  String dayAtTime(String day, String time);

  /// No description provided for @windowSame.
  ///
  /// In he, this message translates to:
  /// **'{day} · {from}–{to}'**
  String windowSame(String day, String from, String to);

  /// No description provided for @windowDiff.
  ///
  /// In he, this message translates to:
  /// **'{from} – {to}'**
  String windowDiff(String from, String to);

  /// No description provided for @priceShekel.
  ///
  /// In he, this message translates to:
  /// **'₪{amount}'**
  String priceShekel(String amount);

  /// No description provided for @navHome.
  ///
  /// In he, this message translates to:
  /// **'בית'**
  String get navHome;

  /// No description provided for @navParking.
  ///
  /// In he, this message translates to:
  /// **'חניה'**
  String get navParking;

  /// No description provided for @navPackages.
  ///
  /// In he, this message translates to:
  /// **'חבילות'**
  String get navPackages;

  /// No description provided for @navMe.
  ///
  /// In he, this message translates to:
  /// **'אני'**
  String get navMe;

  /// No description provided for @notificationsTooltip.
  ///
  /// In he, this message translates to:
  /// **'התראות'**
  String get notificationsTooltip;

  /// No description provided for @paymentNotice.
  ///
  /// In he, this message translates to:
  /// **'התשלום מתבצע ישירות בין השכנים (מזומן, ביט, פייבוקס…). האפליקציה לא מעבדת ולא מחזיקה כסף.'**
  String get paymentNotice;

  /// No description provided for @demoBadge.
  ///
  /// In he, this message translates to:
  /// **'הדגמה'**
  String get demoBadge;

  /// No description provided for @demoNote.
  ///
  /// In he, this message translates to:
  /// **'זהו אב־טיפוס עם נתוני דוגמה. שום דבר לא נשמר בשרת.'**
  String get demoNote;

  /// No description provided for @statusCompleted.
  ///
  /// In he, this message translates to:
  /// **'הושלם'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In he, this message translates to:
  /// **'בוטל'**
  String get statusCancelled;

  /// No description provided for @statusExpired.
  ///
  /// In he, this message translates to:
  /// **'פג תוקף'**
  String get statusExpired;

  /// No description provided for @statusDeclined.
  ///
  /// In he, this message translates to:
  /// **'נדחה'**
  String get statusDeclined;

  /// No description provided for @statusActive.
  ///
  /// In he, this message translates to:
  /// **'פעיל'**
  String get statusActive;

  /// No description provided for @statusAvailable.
  ///
  /// In he, this message translates to:
  /// **'פנויה'**
  String get statusAvailable;

  /// No description provided for @statusReserved.
  ///
  /// In he, this message translates to:
  /// **'שמורה'**
  String get statusReserved;

  /// No description provided for @welcomeTitle.
  ///
  /// In he, this message translates to:
  /// **'חניה, עזרה הדדית, והכול בבניין שלכם'**
  String get welcomeTitle;

  /// No description provided for @welcomeBullet1.
  ///
  /// In he, this message translates to:
  /// **'שתפו חניה פנויה עם השכנים'**
  String get welcomeBullet1;

  /// No description provided for @welcomeBullet2.
  ///
  /// In he, this message translates to:
  /// **'בקשו או הציעו איסוף חבילה'**
  String get welcomeBullet2;

  /// No description provided for @welcomeBullet3.
  ///
  /// In he, this message translates to:
  /// **'רק תושבים מאומתים. הפרטיות שלכם קודם.'**
  String get welcomeBullet3;

  /// No description provided for @getStarted.
  ///
  /// In he, this message translates to:
  /// **'התחלה'**
  String get getStarted;

  /// No description provided for @continueWithGoogle.
  ///
  /// In he, this message translates to:
  /// **'המשך עם Google'**
  String get continueWithGoogle;

  /// No description provided for @signInFailed.
  ///
  /// In he, this message translates to:
  /// **'ההתחברות נכשלה. נסו שוב.'**
  String get signInFailed;

  /// No description provided for @loadFailed.
  ///
  /// In he, this message translates to:
  /// **'הטעינה נכשלה. בדקו את החיבור ונסו שוב.'**
  String get loadFailed;

  /// No description provided for @skipToDemo.
  ///
  /// In he, this message translates to:
  /// **'דלגו להדגמה (ללא הרשמה)'**
  String get skipToDemo;

  /// No description provided for @phoneTitle.
  ///
  /// In he, this message translates to:
  /// **'מה מספר הטלפון שלכם?'**
  String get phoneTitle;

  /// No description provided for @phoneSubtitle.
  ///
  /// In he, this message translates to:
  /// **'נשלח אליכם קוד אימות ב־SMS'**
  String get phoneSubtitle;

  /// No description provided for @sendCode.
  ///
  /// In he, this message translates to:
  /// **'שלחו קוד'**
  String get sendCode;

  /// No description provided for @phoneInvalid.
  ///
  /// In he, this message translates to:
  /// **'מספר הטלפון לא תקין'**
  String get phoneInvalid;

  /// No description provided for @otpTitle.
  ///
  /// In he, this message translates to:
  /// **'הקלידו את הקוד'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In he, this message translates to:
  /// **'שלחנו קוד אל {phone}'**
  String otpSubtitle(String phone);

  /// No description provided for @otpChange.
  ///
  /// In he, this message translates to:
  /// **'החלפת מספר'**
  String get otpChange;

  /// No description provided for @otpResend.
  ///
  /// In he, this message translates to:
  /// **'שליחה חוזרת'**
  String get otpResend;

  /// No description provided for @otpResendIn.
  ///
  /// In he, this message translates to:
  /// **'שליחה חוזרת בעוד {s} שנ׳'**
  String otpResendIn(String s);

  /// No description provided for @verify.
  ///
  /// In he, this message translates to:
  /// **'אימות'**
  String get verify;

  /// No description provided for @otpDemoHint.
  ///
  /// In he, this message translates to:
  /// **'בהדגמה כל קוד עובד (למשל 123456)'**
  String get otpDemoHint;

  /// No description provided for @legalTitle.
  ///
  /// In he, this message translates to:
  /// **'לפני שממשיכים'**
  String get legalTitle;

  /// No description provided for @legalSubtitle.
  ///
  /// In he, this message translates to:
  /// **'קראו ואשרו את המסמכים הבאים'**
  String get legalSubtitle;

  /// No description provided for @termsOfService.
  ///
  /// In he, this message translates to:
  /// **'תנאי שימוש'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In he, this message translates to:
  /// **'מדיניות פרטיות'**
  String get privacyPolicy;

  /// No description provided for @communityRules.
  ///
  /// In he, this message translates to:
  /// **'כללי הקהילה'**
  String get communityRules;

  /// No description provided for @residentDeclaration.
  ///
  /// In he, this message translates to:
  /// **'הצהרת תושב'**
  String get residentDeclaration;

  /// No description provided for @buildingAgreement.
  ///
  /// In he, this message translates to:
  /// **'הסכם בניין'**
  String get buildingAgreement;

  /// No description provided for @legalVersion.
  ///
  /// In he, this message translates to:
  /// **'גרסה {version}'**
  String legalVersion(String version);

  /// No description provided for @legalRead.
  ///
  /// In he, this message translates to:
  /// **'קריאה'**
  String get legalRead;

  /// No description provided for @legalAccept.
  ///
  /// In he, this message translates to:
  /// **'קראתי ואני מאשר/ת'**
  String get legalAccept;

  /// No description provided for @legalPlaceholderNote.
  ///
  /// In he, this message translates to:
  /// **'מסמך זמני: הנוסח המשפטי המלא יפורסם על ידי בעל האפליקציה.'**
  String get legalPlaceholderNote;

  /// No description provided for @legalAcceptContinue.
  ///
  /// In he, this message translates to:
  /// **'אישור והמשך'**
  String get legalAcceptContinue;

  /// No description provided for @joinTitle.
  ///
  /// In he, this message translates to:
  /// **'באיזה בניין אתם גרים?'**
  String get joinTitle;

  /// No description provided for @joinSubtitle.
  ///
  /// In he, this message translates to:
  /// **'הקלידו את קוד הבניין שקיבלתם מהמנהל'**
  String get joinSubtitle;

  /// No description provided for @joinCodeLabel.
  ///
  /// In he, this message translates to:
  /// **'קוד בניין'**
  String get joinCodeLabel;

  /// No description provided for @joinFind.
  ///
  /// In he, this message translates to:
  /// **'חיפוש בניין'**
  String get joinFind;

  /// No description provided for @joinFound.
  ///
  /// In he, this message translates to:
  /// **'מצאנו את הבניין:'**
  String get joinFound;

  /// No description provided for @joinConfirm.
  ///
  /// In he, this message translates to:
  /// **'כן, זה הבניין שלי'**
  String get joinConfirm;

  /// No description provided for @joinInvalid.
  ///
  /// In he, this message translates to:
  /// **'הקוד לא תקין'**
  String get joinInvalid;

  /// No description provided for @joinDemoHint.
  ///
  /// In he, this message translates to:
  /// **'קוד להדגמה: {code}'**
  String joinDemoHint(String code);

  /// No description provided for @applyTitle.
  ///
  /// In he, this message translates to:
  /// **'בקשת הצטרפות'**
  String get applyTitle;

  /// No description provided for @applySubtitle.
  ///
  /// In he, this message translates to:
  /// **'מנהל הבניין יאמת שאתם גרים כאן'**
  String get applySubtitle;

  /// No description provided for @fullName.
  ///
  /// In he, this message translates to:
  /// **'שם מלא'**
  String get fullName;

  /// No description provided for @apartment.
  ///
  /// In he, this message translates to:
  /// **'דירה'**
  String get apartment;

  /// No description provided for @apartmentPick.
  ///
  /// In he, this message translates to:
  /// **'בחרו דירה'**
  String get apartmentPick;

  /// No description provided for @parkingSpaces.
  ///
  /// In he, this message translates to:
  /// **'חניות'**
  String get parkingSpaces;

  /// No description provided for @parkingOptionalHint.
  ///
  /// In he, this message translates to:
  /// **'אם יש לכם חניה פרטית, בחרו אותה מהרשימה'**
  String get parkingOptionalHint;

  /// No description provided for @noParking.
  ///
  /// In he, this message translates to:
  /// **'אין לי חניה פרטית'**
  String get noParking;

  /// No description provided for @declarationsTitle.
  ///
  /// In he, this message translates to:
  /// **'הצהרות'**
  String get declarationsTitle;

  /// No description provided for @decl1.
  ///
  /// In he, this message translates to:
  /// **'המידע שמסרתי נכון'**
  String get decl1;

  /// No description provided for @decl2.
  ///
  /// In he, this message translates to:
  /// **'אני תושב/ת הבניין'**
  String get decl2;

  /// No description provided for @decl3.
  ///
  /// In he, this message translates to:
  /// **'פרטי הדירה נכונים'**
  String get decl3;

  /// No description provided for @decl4.
  ///
  /// In he, this message translates to:
  /// **'פרטי החניה נכונים'**
  String get decl4;

  /// No description provided for @decl5.
  ///
  /// In he, this message translates to:
  /// **'הבנתי את כללי הקהילה'**
  String get decl5;

  /// No description provided for @submitRequest.
  ///
  /// In he, this message translates to:
  /// **'שליחת בקשה'**
  String get submitRequest;

  /// No description provided for @optionalPhoto.
  ///
  /// In he, this message translates to:
  /// **'תמונת פרופיל (אופציונלי)'**
  String get optionalPhoto;

  /// No description provided for @fieldRequired.
  ///
  /// In he, this message translates to:
  /// **'שדה חובה'**
  String get fieldRequired;

  /// No description provided for @pendingTitle.
  ///
  /// In he, this message translates to:
  /// **'מאמתים שאתם גרים ב{building}'**
  String pendingTitle(String building);

  /// No description provided for @pendingBody.
  ///
  /// In he, this message translates to:
  /// **'בדרך כלל זה לוקח עד יום. נשלח התראה כשתאושרו.'**
  String get pendingBody;

  /// No description provided for @pendingSummary.
  ///
  /// In he, this message translates to:
  /// **'הפרטים ששלחתם'**
  String get pendingSummary;

  /// No description provided for @pendingDemoApprove.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: אשרו אותי כמנהל'**
  String get pendingDemoApprove;

  /// No description provided for @withdrawRequest.
  ///
  /// In he, this message translates to:
  /// **'ביטול הבקשה'**
  String get withdrawRequest;

  /// No description provided for @logOut.
  ///
  /// In he, this message translates to:
  /// **'התנתקות'**
  String get logOut;

  /// No description provided for @homeGreeting.
  ///
  /// In he, this message translates to:
  /// **'שלום {name} 👋'**
  String homeGreeting(String name);

  /// No description provided for @homeQuestion.
  ///
  /// In he, this message translates to:
  /// **'מה אפשר לעשות בבניין עכשיו?'**
  String get homeQuestion;

  /// No description provided for @qaFindParking.
  ///
  /// In he, this message translates to:
  /// **'מצאו חניה'**
  String get qaFindParking;

  /// No description provided for @qaShareParking.
  ///
  /// In he, this message translates to:
  /// **'שתפו את החניה שלי'**
  String get qaShareParking;

  /// No description provided for @qaRequestPickup.
  ///
  /// In he, this message translates to:
  /// **'בקשו איסוף חבילה'**
  String get qaRequestPickup;

  /// No description provided for @qaHelp.
  ///
  /// In he, this message translates to:
  /// **'עזרו לשכן'**
  String get qaHelp;

  /// No description provided for @needsAction.
  ///
  /// In he, this message translates to:
  /// **'דורש את תשומת ליבכם'**
  String get needsAction;

  /// No description provided for @happeningSoon.
  ///
  /// In he, this message translates to:
  /// **'בקרוב'**
  String get happeningSoon;

  /// No description provided for @parkingNow.
  ///
  /// In he, this message translates to:
  /// **'חניות פנויות'**
  String get parkingNow;

  /// No description provided for @pickupNeighbors.
  ///
  /// In he, this message translates to:
  /// **'שכנים שצריכים איסוף'**
  String get pickupNeighbors;

  /// No description provided for @nothingYet.
  ///
  /// In he, this message translates to:
  /// **'עוד אין פעילות בבניין'**
  String get nothingYet;

  /// No description provided for @beFirst.
  ///
  /// In he, this message translates to:
  /// **'היו הראשונים לשתף חניה או לבקש עזרה'**
  String get beFirst;

  /// No description provided for @actRespondRequest.
  ///
  /// In he, this message translates to:
  /// **'{name} ביקש/ה את חניה {space}'**
  String actRespondRequest(String name, String space);

  /// No description provided for @actConfirmReservation.
  ///
  /// In he, this message translates to:
  /// **'אשרו את ההזמנה של חניה {space}'**
  String actConfirmReservation(String space);

  /// No description provided for @actShowCode.
  ///
  /// In he, this message translates to:
  /// **'הראו לשכן את קוד המסירה'**
  String get actShowCode;

  /// No description provided for @actHelperArrived.
  ///
  /// In he, this message translates to:
  /// **'{name} הגיע/ה עם החבילה'**
  String actHelperArrived(String name);

  /// No description provided for @actViewPhoto.
  ///
  /// In he, this message translates to:
  /// **'החבילה הושארה ליד הדלת — צפו בתמונה'**
  String get actViewPhoto;

  /// No description provided for @actPayPay.
  ///
  /// In he, this message translates to:
  /// **'סמנו ששילמתם ₪{amount} ל{name}'**
  String actPayPay(String amount, String name);

  /// No description provided for @actPayReceived.
  ///
  /// In he, this message translates to:
  /// **'{name} אומר/ת ששילם/ה ₪{amount}'**
  String actPayReceived(String amount, String name);

  /// No description provided for @actRate.
  ///
  /// In he, this message translates to:
  /// **'דרגו את {name}'**
  String actRate(String name);

  /// No description provided for @actOfferReceived.
  ///
  /// In he, this message translates to:
  /// **'{name} הציע/ה לאסוף את החבילה'**
  String actOfferReceived(String name);

  /// No description provided for @actHelperJob.
  ///
  /// In he, this message translates to:
  /// **'איסוף עבור {name}'**
  String actHelperJob(String name);

  /// No description provided for @soonReservation.
  ///
  /// In he, this message translates to:
  /// **'חניה {space} · {window}'**
  String soonReservation(String space, String window);

  /// No description provided for @soonJob.
  ///
  /// In he, this message translates to:
  /// **'איסוף: {place}'**
  String soonJob(String place);

  /// No description provided for @parkingTitle.
  ///
  /// In he, this message translates to:
  /// **'חניה'**
  String get parkingTitle;

  /// No description provided for @segFind.
  ///
  /// In he, this message translates to:
  /// **'חיפוש'**
  String get segFind;

  /// No description provided for @segMine.
  ///
  /// In he, this message translates to:
  /// **'שלי'**
  String get segMine;

  /// No description provided for @segSharing.
  ///
  /// In he, this message translates to:
  /// **'שיתוף'**
  String get segSharing;

  /// No description provided for @segRenting.
  ///
  /// In he, this message translates to:
  /// **'שכירות'**
  String get segRenting;

  /// No description provided for @whenNeedParking.
  ///
  /// In he, this message translates to:
  /// **'מתי צריך חניה?'**
  String get whenNeedParking;

  /// No description provided for @presetTonight.
  ///
  /// In he, this message translates to:
  /// **'הערב'**
  String get presetTonight;

  /// No description provided for @presetTomorrow.
  ///
  /// In he, this message translates to:
  /// **'מחר'**
  String get presetTomorrow;

  /// No description provided for @presetWeek.
  ///
  /// In he, this message translates to:
  /// **'השבוע'**
  String get presetWeek;

  /// No description provided for @fromLabel.
  ///
  /// In he, this message translates to:
  /// **'מ־'**
  String get fromLabel;

  /// No description provided for @toLabel.
  ///
  /// In he, this message translates to:
  /// **'עד'**
  String get toLabel;

  /// No description provided for @showAllUpcoming.
  ///
  /// In he, this message translates to:
  /// **'הצגת כל הקרובות'**
  String get showAllUpcoming;

  /// No description provided for @coversYourTime.
  ///
  /// In he, this message translates to:
  /// **'מכסה את הזמן שלכם'**
  String get coversYourTime;

  /// No description provided for @instantBadge.
  ///
  /// In he, this message translates to:
  /// **'הזמנה מיידית'**
  String get instantBadge;

  /// No description provided for @approvalBadge.
  ///
  /// In he, this message translates to:
  /// **'באישור בעל החניה'**
  String get approvalBadge;

  /// No description provided for @noSpacesTitle.
  ///
  /// In he, this message translates to:
  /// **'אין חניות פנויות בזמנים האלה'**
  String get noSpacesTitle;

  /// No description provided for @noSpacesMsg.
  ///
  /// In he, this message translates to:
  /// **'נסו להרחיב את הטווח או להציג את כל הקרובות'**
  String get noSpacesMsg;

  /// No description provided for @parkingLabel.
  ///
  /// In he, this message translates to:
  /// **'חניה {space}'**
  String parkingLabel(String space);

  /// No description provided for @listingDetailTitle.
  ///
  /// In he, this message translates to:
  /// **'פרטי החניה'**
  String get listingDetailTitle;

  /// No description provided for @requestAction.
  ///
  /// In he, this message translates to:
  /// **'שליחת בקשה'**
  String get requestAction;

  /// No description provided for @reserveNow.
  ///
  /// In he, this message translates to:
  /// **'הזמינו עכשיו'**
  String get reserveNow;

  /// No description provided for @ownListing.
  ///
  /// In he, this message translates to:
  /// **'זו החניה שלכם'**
  String get ownListing;

  /// No description provided for @offeredBy.
  ///
  /// In he, this message translates to:
  /// **'מוצעת על ידי'**
  String get offeredBy;

  /// No description provided for @whenLabel.
  ///
  /// In he, this message translates to:
  /// **'מתי'**
  String get whenLabel;

  /// No description provided for @priceLabel.
  ///
  /// In he, this message translates to:
  /// **'מחיר'**
  String get priceLabel;

  /// No description provided for @descriptionLabel.
  ///
  /// In he, this message translates to:
  /// **'תיאור'**
  String get descriptionLabel;

  /// No description provided for @reviewTitle.
  ///
  /// In he, this message translates to:
  /// **'סקירה ושליחה'**
  String get reviewTitle;

  /// No description provided for @vehiclePlate.
  ///
  /// In he, this message translates to:
  /// **'מספר רכב (אופציונלי)'**
  String get vehiclePlate;

  /// No description provided for @noteToOwner.
  ///
  /// In he, this message translates to:
  /// **'הערה לבעל החניה'**
  String get noteToOwner;

  /// No description provided for @sendRequest.
  ///
  /// In he, this message translates to:
  /// **'שליחת בקשה'**
  String get sendRequest;

  /// No description provided for @requestSentSnack.
  ///
  /// In he, this message translates to:
  /// **'הבקשה נשלחה לבעל החניה'**
  String get requestSentSnack;

  /// No description provided for @reservedSnack.
  ///
  /// In he, this message translates to:
  /// **'החניה הוזמנה'**
  String get reservedSnack;

  /// No description provided for @slotTaken.
  ///
  /// In he, this message translates to:
  /// **'מישהו הקדים אתכם והחניה כבר נתפסה'**
  String get slotTaken;

  /// No description provided for @publishTitle.
  ///
  /// In he, this message translates to:
  /// **'שיתוף חניה'**
  String get publishTitle;

  /// No description provided for @chooseSpace.
  ///
  /// In he, this message translates to:
  /// **'בחרו חניה'**
  String get chooseSpace;

  /// No description provided for @startsLabel.
  ///
  /// In he, this message translates to:
  /// **'מתחילה'**
  String get startsLabel;

  /// No description provided for @endsLabel.
  ///
  /// In he, this message translates to:
  /// **'מסתיימת'**
  String get endsLabel;

  /// No description provided for @priceInput.
  ///
  /// In he, this message translates to:
  /// **'מחיר (₪)'**
  String get priceInput;

  /// No description provided for @descriptionOptional.
  ///
  /// In he, this message translates to:
  /// **'תיאור (אופציונלי)'**
  String get descriptionOptional;

  /// No description provided for @approveEach.
  ///
  /// In he, this message translates to:
  /// **'אני מאשר/ת כל בקשה'**
  String get approveEach;

  /// No description provided for @approveEachHint.
  ///
  /// In he, this message translates to:
  /// **'כשהאפשרות כבויה — ההזמנה מיידית'**
  String get approveEachHint;

  /// No description provided for @publish.
  ///
  /// In he, this message translates to:
  /// **'פרסום'**
  String get publish;

  /// No description provided for @publishedSnack.
  ///
  /// In he, this message translates to:
  /// **'החניה פורסמה'**
  String get publishedSnack;

  /// No description provided for @noAssignmentTitle.
  ///
  /// In he, this message translates to:
  /// **'אין חניה משויכת אליכם'**
  String get noAssignmentTitle;

  /// No description provided for @noAssignmentMsg.
  ///
  /// In he, this message translates to:
  /// **'כדי לשתף חניה, בקשו שיוך חניה והמנהל יאמת אותה'**
  String get noAssignmentMsg;

  /// No description provided for @requestAssignmentBtn.
  ///
  /// In he, this message translates to:
  /// **'בקשת שיוך חניה'**
  String get requestAssignmentBtn;

  /// No description provided for @overlapError.
  ///
  /// In he, this message translates to:
  /// **'כבר פרסמתם את החניה הזו בזמן הזה'**
  String get overlapError;

  /// No description provided for @invalidWindow.
  ///
  /// In he, this message translates to:
  /// **'זמן הסיום חייב להיות אחרי ההתחלה'**
  String get invalidWindow;

  /// No description provided for @needsResponse.
  ///
  /// In he, this message translates to:
  /// **'ממתין לתגובה'**
  String get needsResponse;

  /// No description provided for @upcoming.
  ///
  /// In he, this message translates to:
  /// **'קרוב'**
  String get upcoming;

  /// No description provided for @past.
  ///
  /// In he, this message translates to:
  /// **'עבר'**
  String get past;

  /// No description provided for @emptySharing.
  ///
  /// In he, this message translates to:
  /// **'עוד לא שיתפתם חניה'**
  String get emptySharing;

  /// No description provided for @emptyRenting.
  ///
  /// In he, this message translates to:
  /// **'אין לכם הזמנות חניה'**
  String get emptyRenting;

  /// No description provided for @requestsTitle.
  ///
  /// In he, this message translates to:
  /// **'בקשות'**
  String get requestsTitle;

  /// No description provided for @noRequestsYet.
  ///
  /// In he, this message translates to:
  /// **'עדיין אין בקשות. החניה שלכם גלויה לשכנים.'**
  String get noRequestsYet;

  /// No description provided for @cancelAvailability.
  ///
  /// In he, this message translates to:
  /// **'ביטול הזמינות'**
  String get cancelAvailability;

  /// No description provided for @cancelAvailabilityBody.
  ///
  /// In he, this message translates to:
  /// **'בקשות שממתינות יידחו והשכנים יקבלו הודעה.'**
  String get cancelAvailabilityBody;

  /// No description provided for @acceptWarn.
  ///
  /// In he, this message translates to:
  /// **'אישור בקשה ידחה את שאר הבקשות לאותו זמן.'**
  String get acceptWarn;

  /// No description provided for @resRequested.
  ///
  /// In he, this message translates to:
  /// **'ממתין לאישור'**
  String get resRequested;

  /// No description provided for @resAccepted.
  ///
  /// In he, this message translates to:
  /// **'אושר — נדרש אישור סופי'**
  String get resAccepted;

  /// No description provided for @resConfirmed.
  ///
  /// In he, this message translates to:
  /// **'הוזמן'**
  String get resConfirmed;

  /// No description provided for @resActive.
  ///
  /// In he, this message translates to:
  /// **'פעיל'**
  String get resActive;

  /// No description provided for @resCompleted.
  ///
  /// In he, this message translates to:
  /// **'הסתיים'**
  String get resCompleted;

  /// No description provided for @stepRequested.
  ///
  /// In he, this message translates to:
  /// **'בקשה'**
  String get stepRequested;

  /// No description provided for @stepAccepted.
  ///
  /// In he, this message translates to:
  /// **'אושר'**
  String get stepAccepted;

  /// No description provided for @stepConfirmed.
  ///
  /// In he, this message translates to:
  /// **'הוזמן'**
  String get stepConfirmed;

  /// No description provided for @stepActive.
  ///
  /// In he, this message translates to:
  /// **'פעיל'**
  String get stepActive;

  /// No description provided for @stepEnded.
  ///
  /// In he, this message translates to:
  /// **'הסתיים'**
  String get stepEnded;

  /// No description provided for @reservationTitle.
  ///
  /// In he, this message translates to:
  /// **'פרטי הזמנה'**
  String get reservationTitle;

  /// No description provided for @confirmReservation.
  ///
  /// In he, this message translates to:
  /// **'אישור הזמנה'**
  String get confirmReservation;

  /// No description provided for @confirmBy.
  ///
  /// In he, this message translates to:
  /// **'יש לאשר עד {time}'**
  String confirmBy(String time);

  /// No description provided for @confirmSheetBody.
  ///
  /// In he, this message translates to:
  /// **'התשלום מתבצע ישירות בינכם ל{name}. האפליקציה לא מעבדת ולא מחזיקה כסף.'**
  String confirmSheetBody(String name);

  /// No description provided for @contactAfter.
  ///
  /// In he, this message translates to:
  /// **'פרטי הקשר יופיעו אחרי אישור סופי'**
  String get contactAfter;

  /// No description provided for @vehicleLabel.
  ///
  /// In he, this message translates to:
  /// **'רכב'**
  String get vehicleLabel;

  /// No description provided for @noteLabel.
  ///
  /// In he, this message translates to:
  /// **'הערה'**
  String get noteLabel;

  /// No description provided for @demoAcceptReq.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: {name} מאשר/ת את הבקשה'**
  String demoAcceptReq(String name);

  /// No description provided for @demoEndBooking.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: זמן ההזמנה הסתיים'**
  String get demoEndBooking;

  /// No description provided for @mySpacesTitle.
  ///
  /// In he, this message translates to:
  /// **'החניות שלי'**
  String get mySpacesTitle;

  /// No description provided for @assignActive.
  ///
  /// In he, this message translates to:
  /// **'מאומתת'**
  String get assignActive;

  /// No description provided for @assignRequested.
  ///
  /// In he, this message translates to:
  /// **'ממתינה לאימות'**
  String get assignRequested;

  /// No description provided for @assignRejected.
  ///
  /// In he, this message translates to:
  /// **'נדחתה'**
  String get assignRejected;

  /// No description provided for @assignEnded.
  ///
  /// In he, this message translates to:
  /// **'הסתיימה'**
  String get assignEnded;

  /// No description provided for @withdrawRequestShort.
  ///
  /// In he, this message translates to:
  /// **'ביטול בקשה'**
  String get withdrawRequestShort;

  /// No description provided for @noSpacesLinked.
  ///
  /// In he, this message translates to:
  /// **'אין חניות משויכות אליכם'**
  String get noSpacesLinked;

  /// No description provided for @requestAssignTitle.
  ///
  /// In he, this message translates to:
  /// **'בקשת שיוך חניה'**
  String get requestAssignTitle;

  /// No description provided for @assignHint.
  ///
  /// In he, this message translates to:
  /// **'המנהל יוודא שהחניה באמת שלכם לפני ששייך אותה אליכם.'**
  String get assignHint;

  /// No description provided for @pickSpace.
  ///
  /// In he, this message translates to:
  /// **'בחרו חניה מהרשימה'**
  String get pickSpace;

  /// No description provided for @sendAssignRequest.
  ///
  /// In he, this message translates to:
  /// **'שליחת בקשה למנהל'**
  String get sendAssignRequest;

  /// No description provided for @assignSentSnack.
  ///
  /// In he, this message translates to:
  /// **'הבקשה נשלחה למנהל'**
  String get assignSentSnack;

  /// No description provided for @cancelBookingTitle.
  ///
  /// In he, this message translates to:
  /// **'ביטול הזמנה'**
  String get cancelBookingTitle;

  /// No description provided for @pkgTitle.
  ///
  /// In he, this message translates to:
  /// **'חבילות'**
  String get pkgTitle;

  /// No description provided for @segHelp.
  ///
  /// In he, this message translates to:
  /// **'עזרה'**
  String get segHelp;

  /// No description provided for @segMyRequests.
  ///
  /// In he, this message translates to:
  /// **'הבקשות שלי'**
  String get segMyRequests;

  /// No description provided for @segMyOffers.
  ///
  /// In he, this message translates to:
  /// **'ההצעות שלי'**
  String get segMyOffers;

  /// No description provided for @filterToday.
  ///
  /// In he, this message translates to:
  /// **'היום'**
  String get filterToday;

  /// No description provided for @filterReward.
  ///
  /// In he, this message translates to:
  /// **'תגמול גבוה'**
  String get filterReward;

  /// No description provided for @rewardLabel.
  ///
  /// In he, this message translates to:
  /// **'תגמול'**
  String get rewardLabel;

  /// No description provided for @doorOkBadge.
  ///
  /// In he, this message translates to:
  /// **'אפשר להשאיר ליד הדלת'**
  String get doorOkBadge;

  /// No description provided for @noRequestsTitle.
  ///
  /// In he, this message translates to:
  /// **'אף אחד לא צריך איסוף כרגע 🎉'**
  String get noRequestsTitle;

  /// No description provided for @noRequestsMsg.
  ///
  /// In he, this message translates to:
  /// **'יש לכם משהו לאסוף? בקשו משכן.'**
  String get noRequestsMsg;

  /// No description provided for @newPickupTitle.
  ///
  /// In he, this message translates to:
  /// **'בקשת איסוף חבילה'**
  String get newPickupTitle;

  /// No description provided for @pickupLocation.
  ///
  /// In he, this message translates to:
  /// **'מיקום האיסוף'**
  String get pickupLocation;

  /// No description provided for @pickupLocationHint.
  ///
  /// In he, this message translates to:
  /// **'למשל: קניון עזריאלי'**
  String get pickupLocationHint;

  /// No description provided for @pkgDescription.
  ///
  /// In he, this message translates to:
  /// **'תיאור החבילה'**
  String get pkgDescription;

  /// No description provided for @pkgDescriptionHint.
  ///
  /// In he, this message translates to:
  /// **'קופסה קטנה, כ־1 ק״ג'**
  String get pkgDescriptionHint;

  /// No description provided for @deadlineLabel.
  ///
  /// In he, this message translates to:
  /// **'עד מתי'**
  String get deadlineLabel;

  /// No description provided for @rewardChoose.
  ///
  /// In he, this message translates to:
  /// **'תגמול'**
  String get rewardChoose;

  /// No description provided for @notesLabel.
  ///
  /// In he, this message translates to:
  /// **'הערות'**
  String get notesLabel;

  /// No description provided for @pickupRef.
  ///
  /// In he, this message translates to:
  /// **'מספר הזמנה / קוד איסוף'**
  String get pickupRef;

  /// No description provided for @pickupRefHint.
  ///
  /// In he, this message translates to:
  /// **'פרטי — יישלח רק לשכן שתבחרו'**
  String get pickupRefHint;

  /// No description provided for @handoffPlace.
  ///
  /// In he, this message translates to:
  /// **'מקום המסירה'**
  String get handoffPlace;

  /// No description provided for @defaultLobby.
  ///
  /// In he, this message translates to:
  /// **'לובי הבניין'**
  String get defaultLobby;

  /// No description provided for @doorToggle.
  ///
  /// In he, this message translates to:
  /// **'אפשר להשאיר את החבילה ליד דלת הדירה'**
  String get doorToggle;

  /// No description provided for @doorToggleHint.
  ///
  /// In he, this message translates to:
  /// **'השכן חייב לשלוח לכם תמונה כהוכחה'**
  String get doorToggleHint;

  /// No description provided for @ackProhibited.
  ///
  /// In he, this message translates to:
  /// **'אין בחבילה פריטים אסורים (מזומן, מסמכים מזהים, תרופות…)'**
  String get ackProhibited;

  /// No description provided for @ackThirdParty.
  ///
  /// In he, this message translates to:
  /// **'נקודת האיסוף מאפשרת לאסוף עבורי'**
  String get ackThirdParty;

  /// No description provided for @postRequest.
  ///
  /// In he, this message translates to:
  /// **'פרסום הבקשה'**
  String get postRequest;

  /// No description provided for @postedSnack.
  ///
  /// In he, this message translates to:
  /// **'הבקשה פורסמה'**
  String get postedSnack;

  /// No description provided for @deadlineTooSoon.
  ///
  /// In he, this message translates to:
  /// **'הדד־ליין חייב להיות לפחות 30 דקות קדימה'**
  String get deadlineTooSoon;

  /// No description provided for @offerToPickup.
  ///
  /// In he, this message translates to:
  /// **'אני אאסוף'**
  String get offerToPickup;

  /// No description provided for @withdrawOffer.
  ///
  /// In he, this message translates to:
  /// **'ביטול ההצעה'**
  String get withdrawOffer;

  /// No description provided for @offerSheetTitle.
  ///
  /// In he, this message translates to:
  /// **'הצעת איסוף'**
  String get offerSheetTitle;

  /// No description provided for @plannedTime.
  ///
  /// In he, this message translates to:
  /// **'מתי תגיעו לשם? (אופציונלי)'**
  String get plannedTime;

  /// No description provided for @messageOptional.
  ///
  /// In he, this message translates to:
  /// **'הודעה (אופציונלי)'**
  String get messageOptional;

  /// No description provided for @sendOffer.
  ///
  /// In he, this message translates to:
  /// **'שליחת הצעה'**
  String get sendOffer;

  /// No description provided for @offerSentSnack.
  ///
  /// In he, this message translates to:
  /// **'ההצעה נשלחה'**
  String get offerSentSnack;

  /// No description provided for @offerPending.
  ///
  /// In he, this message translates to:
  /// **'ההצעה שלכם נשלחה וממתינה לאישור'**
  String get offerPending;

  /// No description provided for @hiddenDetails.
  ///
  /// In he, this message translates to:
  /// **'מספר הדירה ופרטי האיסוף יופיעו אחרי שההצעה שלכם תאושר.'**
  String get hiddenDetails;

  /// No description provided for @reqOpen.
  ///
  /// In he, this message translates to:
  /// **'פתוחה'**
  String get reqOpen;

  /// No description provided for @reqOffers.
  ///
  /// In he, this message translates to:
  /// **'התקבלו הצעות'**
  String get reqOffers;

  /// No description provided for @reqAccepted.
  ///
  /// In he, this message translates to:
  /// **'ההצעה אושרה'**
  String get reqAccepted;

  /// No description provided for @reqCollected.
  ///
  /// In he, this message translates to:
  /// **'נאסף'**
  String get reqCollected;

  /// No description provided for @reqDelivered.
  ///
  /// In he, this message translates to:
  /// **'נמסר'**
  String get reqDelivered;

  /// No description provided for @reqCompleted.
  ///
  /// In he, this message translates to:
  /// **'הושלם'**
  String get reqCompleted;

  /// No description provided for @reqCancelled.
  ///
  /// In he, this message translates to:
  /// **'בוטל'**
  String get reqCancelled;

  /// No description provided for @reqExpired.
  ///
  /// In he, this message translates to:
  /// **'פג תוקף'**
  String get reqExpired;

  /// No description provided for @reqDisputed.
  ///
  /// In he, this message translates to:
  /// **'בבדיקה'**
  String get reqDisputed;

  /// No description provided for @stOpen.
  ///
  /// In he, this message translates to:
  /// **'פתוח'**
  String get stOpen;

  /// No description provided for @stOffers.
  ///
  /// In he, this message translates to:
  /// **'הצעות'**
  String get stOffers;

  /// No description provided for @stAccepted.
  ///
  /// In he, this message translates to:
  /// **'אושר'**
  String get stAccepted;

  /// No description provided for @stCollected.
  ///
  /// In he, this message translates to:
  /// **'נאסף'**
  String get stCollected;

  /// No description provided for @stDelivered.
  ///
  /// In he, this message translates to:
  /// **'נמסר'**
  String get stDelivered;

  /// No description provided for @stCompleted.
  ///
  /// In he, this message translates to:
  /// **'הושלם'**
  String get stCompleted;

  /// No description provided for @offersTitle.
  ///
  /// In he, this message translates to:
  /// **'הצעות'**
  String get offersTitle;

  /// No description provided for @noOffersYet.
  ///
  /// In he, this message translates to:
  /// **'השכנים קיבלו הודעה. נעדכן כשמישהו יציע לאסוף.'**
  String get noOffersYet;

  /// No description provided for @offerAt.
  ///
  /// In he, this message translates to:
  /// **'יגיע בסביבות {time}'**
  String offerAt(String time);

  /// No description provided for @yourHelper.
  ///
  /// In he, this message translates to:
  /// **'השכן/ה שאוסף/ת'**
  String get yourHelper;

  /// No description provided for @codePanelTitle.
  ///
  /// In he, this message translates to:
  /// **'קוד המסירה שלכם'**
  String get codePanelTitle;

  /// No description provided for @codeHint.
  ///
  /// In he, this message translates to:
  /// **'אמרו את הקוד רק כשהחבילה בידיכם'**
  String get codeHint;

  /// No description provided for @regenerateCode.
  ///
  /// In he, this message translates to:
  /// **'יצירת קוד חדש'**
  String get regenerateCode;

  /// No description provided for @regenLeft.
  ///
  /// In he, this message translates to:
  /// **'נותרו {n}'**
  String regenLeft(String n);

  /// No description provided for @allowDoor.
  ///
  /// In he, this message translates to:
  /// **'אפשרו להשאיר ליד הדלת'**
  String get allowDoor;

  /// No description provided for @doorAllowedNote.
  ///
  /// In he, this message translates to:
  /// **'מאושר — השכן יצרף תמונה כהוכחה'**
  String get doorAllowedNote;

  /// No description provided for @arrivalBanner.
  ///
  /// In he, this message translates to:
  /// **'{name} הגיע/ה עם החבילה'**
  String arrivalBanner(String name);

  /// No description provided for @deliveryPhoto.
  ///
  /// In he, this message translates to:
  /// **'תמונת מסירה'**
  String get deliveryPhoto;

  /// No description provided for @photoTakenAt.
  ///
  /// In he, this message translates to:
  /// **'צולם {time} על ידי {name}'**
  String photoTakenAt(String name, String time);

  /// No description provided for @confirmReceived.
  ///
  /// In he, this message translates to:
  /// **'אישור קבלה'**
  String get confirmReceived;

  /// No description provided for @reportProblem.
  ///
  /// In he, this message translates to:
  /// **'דיווח על בעיה'**
  String get reportProblem;

  /// No description provided for @autoConfirmNote.
  ///
  /// In he, this message translates to:
  /// **'ללא תגובה, יאושר אוטומטית בעוד {time}'**
  String autoConfirmNote(String time);

  /// No description provided for @cancelRequestBtn.
  ///
  /// In he, this message translates to:
  /// **'ביטול הבקשה'**
  String get cancelRequestBtn;

  /// No description provided for @jobTitle.
  ///
  /// In he, this message translates to:
  /// **'משימת איסוף'**
  String get jobTitle;

  /// No description provided for @pickupBlock.
  ///
  /// In he, this message translates to:
  /// **'איסוף'**
  String get pickupBlock;

  /// No description provided for @deliverTo.
  ///
  /// In he, this message translates to:
  /// **'מסירה'**
  String get deliverTo;

  /// No description provided for @apartmentLabel.
  ///
  /// In he, this message translates to:
  /// **'דירה {apt}'**
  String apartmentLabel(String apt);

  /// No description provided for @pickupRefLabel.
  ///
  /// In he, this message translates to:
  /// **'מספר איסוף'**
  String get pickupRefLabel;

  /// No description provided for @iPickedUp.
  ///
  /// In he, this message translates to:
  /// **'אספתי את החבילה'**
  String get iPickedUp;

  /// No description provided for @imHere.
  ///
  /// In he, this message translates to:
  /// **'הגעתי'**
  String get imHere;

  /// No description provided for @arrivalSent.
  ///
  /// In he, this message translates to:
  /// **'הודענו ל{name} שהגעתם'**
  String arrivalSent(String name);

  /// No description provided for @enterCode.
  ///
  /// In he, this message translates to:
  /// **'הזנת קוד מסירה'**
  String get enterCode;

  /// No description provided for @cantHandOver.
  ///
  /// In he, this message translates to:
  /// **'לא מצליחים למסור?'**
  String get cantHandOver;

  /// No description provided for @withdrawJob.
  ///
  /// In he, this message translates to:
  /// **'ביטול המשימה'**
  String get withdrawJob;

  /// No description provided for @codeEntryTitle.
  ///
  /// In he, this message translates to:
  /// **'קוד מסירה'**
  String get codeEntryTitle;

  /// No description provided for @codeEntryHint.
  ///
  /// In he, this message translates to:
  /// **'בקשו מ{name} את הקוד בן 4 הספרות'**
  String codeEntryHint(String name);

  /// No description provided for @confirmDelivery.
  ///
  /// In he, this message translates to:
  /// **'אישור מסירה'**
  String get confirmDelivery;

  /// No description provided for @wrongCode.
  ///
  /// In he, this message translates to:
  /// **'הקוד לא תואם. נותרו {n} ניסיונות.'**
  String wrongCode(String n);

  /// No description provided for @lockedCode.
  ///
  /// In he, this message translates to:
  /// **'יותר מדי ניסיונות. נסו שוב בעוד {time}.'**
  String lockedCode(String time);

  /// No description provided for @deliveredTitle.
  ///
  /// In he, this message translates to:
  /// **'נמסר! 🎉'**
  String get deliveredTitle;

  /// No description provided for @deliveredBody.
  ///
  /// In he, this message translates to:
  /// **'המסירה אושרה. עכשיו נשאר להסדיר את התשלום.'**
  String get deliveredBody;

  /// No description provided for @methodsTitle.
  ///
  /// In he, this message translates to:
  /// **'איך מוסרים?'**
  String get methodsTitle;

  /// No description provided for @methodPhone.
  ///
  /// In he, this message translates to:
  /// **'קבלו את הקוד בטלפון'**
  String get methodPhone;

  /// No description provided for @methodPhoneHint.
  ///
  /// In he, this message translates to:
  /// **'המבקש מקריא לכם את הקוד גם אם הוא לא בבית'**
  String get methodPhoneHint;

  /// No description provided for @methodDoor.
  ///
  /// In he, this message translates to:
  /// **'השאירו ליד דלת הדירה'**
  String get methodDoor;

  /// No description provided for @methodDoorHint.
  ///
  /// In he, this message translates to:
  /// **'דורש אישור של המבקש ותמונת הוכחה'**
  String get methodDoorHint;

  /// No description provided for @askAllow.
  ///
  /// In he, this message translates to:
  /// **'בקשו מ{name} לאשר'**
  String askAllow(String name);

  /// No description provided for @allowAsked.
  ///
  /// In he, this message translates to:
  /// **'ביקשנו מ{name} לאשר מסירה ליד הדלת'**
  String allowAsked(String name);

  /// No description provided for @methodUnreachable.
  ///
  /// In he, this message translates to:
  /// **'אי אפשר ליצור קשר'**
  String get methodUnreachable;

  /// No description provided for @methodUnreachableHint.
  ///
  /// In he, this message translates to:
  /// **'החבילה נשארת אצלכם והמקרה עובר לבדיקה'**
  String get methodUnreachableHint;

  /// No description provided for @allowSheetTitle.
  ///
  /// In he, this message translates to:
  /// **'השכן כאן עם החבילה'**
  String get allowSheetTitle;

  /// No description provided for @allowSheetBody.
  ///
  /// In he, this message translates to:
  /// **'אפשר לרדת לקבל, להקריא את הקוד, או לאשר להשאיר את החבילה ליד הדלת. תקבלו תמונה כהוכחה.'**
  String get allowSheetBody;

  /// No description provided for @showMyCode.
  ///
  /// In he, this message translates to:
  /// **'הציגו את הקוד שלי'**
  String get showMyCode;

  /// No description provided for @allowLeaving.
  ///
  /// In he, this message translates to:
  /// **'אפשרו להשאיר ליד הדלת'**
  String get allowLeaving;

  /// No description provided for @illComeDown.
  ///
  /// In he, this message translates to:
  /// **'אני יורד/ת'**
  String get illComeDown;

  /// No description provided for @doorPhotoTitle.
  ///
  /// In he, this message translates to:
  /// **'מסירה ליד הדלת'**
  String get doorPhotoTitle;

  /// No description provided for @doorPhotoGuide.
  ///
  /// In he, this message translates to:
  /// **'צלמו את החבילה ליד הדלת. הימנעו מצילום אנשים ודלתות של שכנים אחרים.'**
  String get doorPhotoGuide;

  /// No description provided for @takePhoto.
  ///
  /// In he, this message translates to:
  /// **'צילום'**
  String get takePhoto;

  /// No description provided for @retake.
  ///
  /// In he, this message translates to:
  /// **'צילום מחדש'**
  String get retake;

  /// No description provided for @submitDelivery.
  ///
  /// In he, this message translates to:
  /// **'שליחת המסירה'**
  String get submitDelivery;

  /// No description provided for @doorPhotoSuccess.
  ///
  /// In he, this message translates to:
  /// **'נמסר — הבקשה עודכנה'**
  String get doorPhotoSuccess;

  /// No description provided for @cameraDemoHint.
  ///
  /// In he, this message translates to:
  /// **'בהדגמה מוצגת תמונת דוגמה במקום מצלמה'**
  String get cameraDemoHint;

  /// No description provided for @photoViewerTitle.
  ///
  /// In he, this message translates to:
  /// **'תמונת מסירה'**
  String get photoViewerTitle;

  /// No description provided for @photoSample.
  ///
  /// In he, this message translates to:
  /// **'תמונה לדוגמה'**
  String get photoSample;

  /// No description provided for @photoMeta.
  ///
  /// In he, this message translates to:
  /// **'צולם {time} · הועלה על ידי {name}'**
  String photoMeta(String name, String time);

  /// No description provided for @photoNote.
  ///
  /// In he, this message translates to:
  /// **'הערת השליח: {note}'**
  String photoNote(String note);

  /// No description provided for @photoRetention.
  ///
  /// In he, this message translates to:
  /// **'התמונה נשמרת 30 ימים'**
  String get photoRetention;

  /// No description provided for @demoOffer.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: שכן מציע לאסוף'**
  String get demoOffer;

  /// No description provided for @demoCollected.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: השכן אסף את החבילה'**
  String get demoCollected;

  /// No description provided for @demoArrival.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: השכן הגיע עם החבילה'**
  String get demoArrival;

  /// No description provided for @demoDoorDelivery.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: השכן השאיר ליד הדלת עם תמונה'**
  String get demoDoorDelivery;

  /// No description provided for @payTitle.
  ///
  /// In he, this message translates to:
  /// **'תשלום'**
  String get payTitle;

  /// No description provided for @iPaid.
  ///
  /// In he, this message translates to:
  /// **'אני שילמתי'**
  String get iPaid;

  /// No description provided for @waitingConfirm.
  ///
  /// In he, this message translates to:
  /// **'ממתינים ש{name} יאשר/תאשר'**
  String waitingConfirm(String name);

  /// No description provided for @waitingPay.
  ///
  /// In he, this message translates to:
  /// **'ממתינים ש{name} ישלם/תשלם'**
  String waitingPay(String name);

  /// No description provided for @saidPaid.
  ///
  /// In he, this message translates to:
  /// **'{name} אומר/ת ששילם/ה ₪{amount}'**
  String saidPaid(String amount, String name);

  /// No description provided for @paymentReceived.
  ///
  /// In he, this message translates to:
  /// **'התשלום התקבל'**
  String get paymentReceived;

  /// No description provided for @notReceived.
  ///
  /// In he, this message translates to:
  /// **'לא התקבל'**
  String get notReceived;

  /// No description provided for @noPaymentNeeded.
  ///
  /// In he, this message translates to:
  /// **'אין צורך בתשלום'**
  String get noPaymentNeeded;

  /// No description provided for @settledLabel.
  ///
  /// In he, this message translates to:
  /// **'התשלום הושלם'**
  String get settledLabel;

  /// No description provided for @paymentCancelled.
  ///
  /// In he, this message translates to:
  /// **'התשלום בוטל'**
  String get paymentCancelled;

  /// No description provided for @youPayTo.
  ///
  /// In he, this message translates to:
  /// **'אתם משלמים ₪{amount} ל{name}'**
  String youPayTo(String amount, String name);

  /// No description provided for @youReceiveFrom.
  ///
  /// In he, this message translates to:
  /// **'אתם מקבלים ₪{amount} מ{name}'**
  String youReceiveFrom(String amount, String name);

  /// No description provided for @payPending.
  ///
  /// In he, this message translates to:
  /// **'ממתין לתשלום'**
  String get payPending;

  /// No description provided for @payConfirmed.
  ///
  /// In he, this message translates to:
  /// **'סומן כשולם'**
  String get payConfirmed;

  /// No description provided for @paySettled.
  ///
  /// In he, this message translates to:
  /// **'שולם'**
  String get paySettled;

  /// No description provided for @payCancelled.
  ///
  /// In he, this message translates to:
  /// **'בוטל'**
  String get payCancelled;

  /// No description provided for @demoPayerPaid.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: {name} מסמן/ת ששילם/ה'**
  String demoPayerPaid(String name);

  /// No description provided for @demoPayeeConfirm.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: {name} מאשר/ת קבלת תשלום'**
  String demoPayeeConfirm(String name);

  /// No description provided for @txDetailTitle.
  ///
  /// In he, this message translates to:
  /// **'פרטי עסקה'**
  String get txDetailTitle;

  /// No description provided for @txInProgress.
  ///
  /// In he, this message translates to:
  /// **'בתהליך'**
  String get txInProgress;

  /// No description provided for @txAwaiting.
  ///
  /// In he, this message translates to:
  /// **'ממתינה לאישור תשלום'**
  String get txAwaiting;

  /// No description provided for @txCompleted.
  ///
  /// In he, this message translates to:
  /// **'הושלמה'**
  String get txCompleted;

  /// No description provided for @txCancelled.
  ///
  /// In he, this message translates to:
  /// **'בוטלה'**
  String get txCancelled;

  /// No description provided for @txDisputed.
  ///
  /// In he, this message translates to:
  /// **'בבדיקה'**
  String get txDisputed;

  /// No description provided for @youPaid.
  ///
  /// In he, this message translates to:
  /// **'שילמתם'**
  String get youPaid;

  /// No description provided for @youReceived.
  ///
  /// In he, this message translates to:
  /// **'קיבלתם'**
  String get youReceived;

  /// No description provided for @refundRecord.
  ///
  /// In he, this message translates to:
  /// **'נוצרה רשומת החזר נפרדת'**
  String get refundRecord;

  /// No description provided for @paymentTimeline.
  ///
  /// In he, this message translates to:
  /// **'ציר תשלום'**
  String get paymentTimeline;

  /// No description provided for @counterparty.
  ///
  /// In he, this message translates to:
  /// **'הצד השני'**
  String get counterparty;

  /// No description provided for @txTypeParking.
  ///
  /// In he, this message translates to:
  /// **'חניה'**
  String get txTypeParking;

  /// No description provided for @txTypePickup.
  ///
  /// In he, this message translates to:
  /// **'איסוף חבילה'**
  String get txTypePickup;

  /// No description provided for @historyTitle.
  ///
  /// In he, this message translates to:
  /// **'היסטוריה'**
  String get historyTitle;

  /// No description provided for @filterAll.
  ///
  /// In he, this message translates to:
  /// **'הכול'**
  String get filterAll;

  /// No description provided for @filterParking.
  ///
  /// In he, this message translates to:
  /// **'חניה'**
  String get filterParking;

  /// No description provided for @filterPickups.
  ///
  /// In he, this message translates to:
  /// **'איסופים'**
  String get filterPickups;

  /// No description provided for @filterPaid.
  ///
  /// In he, this message translates to:
  /// **'שילמתי'**
  String get filterPaid;

  /// No description provided for @filterReceived.
  ///
  /// In he, this message translates to:
  /// **'קיבלתי'**
  String get filterReceived;

  /// No description provided for @historyEmpty.
  ///
  /// In he, this message translates to:
  /// **'הפעילות שלכם תופיע כאן'**
  String get historyEmpty;

  /// No description provided for @historyTotals.
  ///
  /// In he, this message translates to:
  /// **'שילמתם ₪{paid} · קיבלתם ₪{earned}'**
  String historyTotals(String earned, String paid);

  /// No description provided for @rateTitle.
  ///
  /// In he, this message translates to:
  /// **'דרגו את {name}'**
  String rateTitle(String name);

  /// No description provided for @rateComment.
  ///
  /// In he, this message translates to:
  /// **'הוסיפו תגובה (אופציונלי)'**
  String get rateComment;

  /// No description provided for @notNow.
  ///
  /// In he, this message translates to:
  /// **'לא עכשיו'**
  String get notNow;

  /// No description provided for @rateThanks.
  ///
  /// In he, this message translates to:
  /// **'תודה על הדירוג'**
  String get rateThanks;

  /// No description provided for @rateHidden.
  ///
  /// In he, this message translates to:
  /// **'הדירוגים מופיעים כששני הצדדים דירגו, או אחרי 14 ימים'**
  String get rateHidden;

  /// No description provided for @rateButton.
  ///
  /// In he, this message translates to:
  /// **'דירוג'**
  String get rateButton;

  /// No description provided for @alreadyRated.
  ///
  /// In he, this message translates to:
  /// **'כבר דירגתם'**
  String get alreadyRated;

  /// No description provided for @cancelTitle.
  ///
  /// In he, this message translates to:
  /// **'ביטול'**
  String get cancelTitle;

  /// No description provided for @consequences.
  ///
  /// In he, this message translates to:
  /// **'מה יקרה:'**
  String get consequences;

  /// No description provided for @consOther.
  ///
  /// In he, this message translates to:
  /// **'הצד השני יקבל הודעה'**
  String get consOther;

  /// No description provided for @consRefund.
  ///
  /// In he, this message translates to:
  /// **'אם כבר שולם — תיווצר רשומת החזר נפרדת'**
  String get consRefund;

  /// No description provided for @consCounter.
  ///
  /// In he, this message translates to:
  /// **'הביטול נספר בדירוג האמינות שלכם'**
  String get consCounter;

  /// No description provided for @confirmCancel.
  ///
  /// In he, this message translates to:
  /// **'אישור ביטול'**
  String get confirmCancel;

  /// No description provided for @keepIt.
  ///
  /// In he, this message translates to:
  /// **'להשאיר'**
  String get keepIt;

  /// No description provided for @cancelledSnack.
  ///
  /// In he, this message translates to:
  /// **'בוטל'**
  String get cancelledSnack;

  /// No description provided for @reportTitle.
  ///
  /// In he, this message translates to:
  /// **'דיווח על בעיה'**
  String get reportTitle;

  /// No description provided for @reportReason.
  ///
  /// In he, this message translates to:
  /// **'סיבה'**
  String get reportReason;

  /// No description provided for @rSpaceOccupied.
  ///
  /// In he, this message translates to:
  /// **'החניה הייתה תפוסה'**
  String get rSpaceOccupied;

  /// No description provided for @rNotDelivered.
  ///
  /// In he, this message translates to:
  /// **'החבילה לא נמסרה'**
  String get rNotDelivered;

  /// No description provided for @rPaymentNotReceived.
  ///
  /// In he, this message translates to:
  /// **'התשלום לא התקבל'**
  String get rPaymentNotReceived;

  /// No description provided for @rUnreachable.
  ///
  /// In he, this message translates to:
  /// **'אי אפשר ליצור קשר עם המבקש'**
  String get rUnreachable;

  /// No description provided for @rOther.
  ///
  /// In he, this message translates to:
  /// **'אחר'**
  String get rOther;

  /// No description provided for @reportDesc.
  ///
  /// In he, this message translates to:
  /// **'מה קרה?'**
  String get reportDesc;

  /// No description provided for @reportNote.
  ///
  /// In he, this message translates to:
  /// **'מנהל הבניין יבדוק תוך 48 שעות, והפעולות האוטומטיות מושהות.'**
  String get reportNote;

  /// No description provided for @submitReport.
  ///
  /// In he, this message translates to:
  /// **'שליחת הדיווח'**
  String get submitReport;

  /// No description provided for @reportSent.
  ///
  /// In he, this message translates to:
  /// **'הדיווח נשלח'**
  String get reportSent;

  /// No description provided for @profileTitle.
  ///
  /// In he, this message translates to:
  /// **'פרופיל שכן'**
  String get profileTitle;

  /// No description provided for @reviewsTitle.
  ///
  /// In he, this message translates to:
  /// **'ביקורות'**
  String get reviewsTitle;

  /// No description provided for @noReviews.
  ///
  /// In he, this message translates to:
  /// **'עדיין אין ביקורות'**
  String get noReviews;

  /// No description provided for @privateInfoNote.
  ///
  /// In he, this message translates to:
  /// **'מספר דירה וטלפון לא מוצגים לשכנים'**
  String get privateInfoNote;

  /// No description provided for @notificationsTitle.
  ///
  /// In he, this message translates to:
  /// **'התראות'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In he, this message translates to:
  /// **'סימון הכול כנקרא'**
  String get markAllRead;

  /// No description provided for @allCaughtUp.
  ///
  /// In he, this message translates to:
  /// **'הכול מעודכן 🎉'**
  String get allCaughtUp;

  /// No description provided for @nParkingRequest.
  ///
  /// In he, this message translates to:
  /// **'{name} ביקש/ה את חניה {space}'**
  String nParkingRequest(String name, String space);

  /// No description provided for @nParkingAccepted.
  ///
  /// In he, this message translates to:
  /// **'{name} אישר/ה — אשרו סופית כדי להזמין'**
  String nParkingAccepted(String name);

  /// No description provided for @nOfferReceived.
  ///
  /// In he, this message translates to:
  /// **'{name} הציע/ה לאסוף את החבילה שלכם'**
  String nOfferReceived(String name);

  /// No description provided for @nCollected.
  ///
  /// In he, this message translates to:
  /// **'{name} אסף/ה את החבילה'**
  String nCollected(String name);

  /// No description provided for @nArrived.
  ///
  /// In he, this message translates to:
  /// **'{name} הגיע/ה עם החבילה'**
  String nArrived(String name);

  /// No description provided for @nDoorDelivered.
  ///
  /// In he, this message translates to:
  /// **'החבילה הושארה ליד הדלת — יש תמונה'**
  String get nDoorDelivered;

  /// No description provided for @nMarkedPaid.
  ///
  /// In he, this message translates to:
  /// **'{name} סימן/ה ששילם/ה'**
  String nMarkedPaid(String name);

  /// No description provided for @nRatingRequested.
  ///
  /// In he, this message translates to:
  /// **'דרגו את {name}'**
  String nRatingRequested(String name);

  /// No description provided for @nApproved.
  ///
  /// In he, this message translates to:
  /// **'אושרתם כתושבי הבניין!'**
  String get nApproved;

  /// No description provided for @agoMinutes.
  ///
  /// In he, this message translates to:
  /// **'לפני {m} דק׳'**
  String agoMinutes(String m);

  /// No description provided for @agoHours.
  ///
  /// In he, this message translates to:
  /// **'לפני {h} שע׳'**
  String agoHours(String h);

  /// No description provided for @agoDays.
  ///
  /// In he, this message translates to:
  /// **'לפני {d} ימים'**
  String agoDays(String d);

  /// No description provided for @meTitle.
  ///
  /// In he, this message translates to:
  /// **'אני'**
  String get meTitle;

  /// No description provided for @apartmentIn.
  ///
  /// In he, this message translates to:
  /// **'דירה {apt} · {building}'**
  String apartmentIn(String apt, String building);

  /// No description provided for @editProfile.
  ///
  /// In he, this message translates to:
  /// **'עריכת פרופיל'**
  String get editProfile;

  /// No description provided for @settingsTitle.
  ///
  /// In he, this message translates to:
  /// **'הגדרות'**
  String get settingsTitle;

  /// No description provided for @helpLabel.
  ///
  /// In he, this message translates to:
  /// **'עזרה ויצירת קשר'**
  String get helpLabel;

  /// No description provided for @adminArea.
  ///
  /// In he, this message translates to:
  /// **'ניהול הבניין'**
  String get adminArea;

  /// No description provided for @platformArea.
  ///
  /// In he, this message translates to:
  /// **'ניהול פלטפורמה'**
  String get platformArea;

  /// No description provided for @languageLabel.
  ///
  /// In he, this message translates to:
  /// **'שפה'**
  String get languageLabel;

  /// No description provided for @hebrew.
  ///
  /// In he, this message translates to:
  /// **'עברית'**
  String get hebrew;

  /// No description provided for @english.
  ///
  /// In he, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @notifSettings.
  ///
  /// In he, this message translates to:
  /// **'התראות'**
  String get notifSettings;

  /// No description provided for @notifNewPickup.
  ///
  /// In he, this message translates to:
  /// **'בקשות איסוף חדשות'**
  String get notifNewPickup;

  /// No description provided for @notifNewParking.
  ///
  /// In he, this message translates to:
  /// **'חניות חדשות'**
  String get notifNewParking;

  /// No description provided for @alwaysOn.
  ///
  /// In he, this message translates to:
  /// **'התראות על עסקאות פעילות תמיד'**
  String get alwaysOn;

  /// No description provided for @legalDocs.
  ///
  /// In he, this message translates to:
  /// **'מסמכים משפטיים'**
  String get legalDocs;

  /// No description provided for @appVersion.
  ///
  /// In he, this message translates to:
  /// **'גרסה'**
  String get appVersion;

  /// No description provided for @deleteAccount.
  ///
  /// In he, this message translates to:
  /// **'מחיקת חשבון'**
  String get deleteAccount;

  /// No description provided for @deleteBlocked.
  ///
  /// In he, this message translates to:
  /// **'אי אפשר למחוק חשבון כשיש עסקאות פעילות'**
  String get deleteBlocked;

  /// No description provided for @showDemoTools.
  ///
  /// In he, this message translates to:
  /// **'הצגת כפתורי הדגמה'**
  String get showDemoTools;

  /// No description provided for @demoSection.
  ///
  /// In he, this message translates to:
  /// **'הדגמה'**
  String get demoSection;

  /// No description provided for @resetDemo.
  ///
  /// In he, this message translates to:
  /// **'איפוס נתוני ההדגמה'**
  String get resetDemo;

  /// No description provided for @serverStatus.
  ///
  /// In he, this message translates to:
  /// **'שרת'**
  String get serverStatus;

  /// No description provided for @serverConnected.
  ///
  /// In he, this message translates to:
  /// **'מחובר ל-Supabase'**
  String get serverConnected;

  /// No description provided for @serverNotConfigured.
  ///
  /// In he, this message translates to:
  /// **'לא מוגדר — נתוני הדגמה בלבד'**
  String get serverNotConfigured;

  /// No description provided for @serverUnreachable.
  ///
  /// In he, this message translates to:
  /// **'אין חיבור לשרת'**
  String get serverUnreachable;

  /// No description provided for @profileEditNote.
  ///
  /// In he, this message translates to:
  /// **'שינוי דירה שולח בקשת הצטרפות חדשה לאישור המנהל.'**
  String get profileEditNote;

  /// No description provided for @adminTitle.
  ///
  /// In he, this message translates to:
  /// **'ניהול הבניין'**
  String get adminTitle;

  /// No description provided for @adminHello.
  ///
  /// In he, this message translates to:
  /// **'שלום, מנהל/ת הבניין'**
  String get adminHello;

  /// No description provided for @adminPendingApps.
  ///
  /// In he, this message translates to:
  /// **'בקשות הצטרפות'**
  String get adminPendingApps;

  /// No description provided for @adminParkingRequests.
  ///
  /// In he, this message translates to:
  /// **'בקשות שיוך חניה'**
  String get adminParkingRequests;

  /// No description provided for @adminDisputes.
  ///
  /// In he, this message translates to:
  /// **'מחלוקות'**
  String get adminDisputes;

  /// No description provided for @adminActivity.
  ///
  /// In he, this message translates to:
  /// **'פעילות בבניין'**
  String get adminActivity;

  /// No description provided for @adminStats.
  ///
  /// In he, this message translates to:
  /// **'סטטיסטיקה'**
  String get adminStats;

  /// No description provided for @adminSettings.
  ///
  /// In he, this message translates to:
  /// **'הגדרות בניין'**
  String get adminSettings;

  /// No description provided for @adminResidents.
  ///
  /// In he, this message translates to:
  /// **'דיירים'**
  String get adminResidents;

  /// No description provided for @adminApartments.
  ///
  /// In he, this message translates to:
  /// **'דירות'**
  String get adminApartments;

  /// No description provided for @adminSpaces.
  ///
  /// In he, this message translates to:
  /// **'חניות'**
  String get adminSpaces;

  /// No description provided for @selfReviewBanner.
  ///
  /// In he, this message translates to:
  /// **'כמנהל/ת היחיד/ה אפשר לאשר את עצמכם. הפעולה מסומנת ביומן הביקורת.'**
  String get selfReviewBanner;

  /// No description provided for @applicationsTitle.
  ///
  /// In he, this message translates to:
  /// **'בקשות הצטרפות'**
  String get applicationsTitle;

  /// No description provided for @tabPending.
  ///
  /// In he, this message translates to:
  /// **'ממתינות'**
  String get tabPending;

  /// No description provided for @tabDecided.
  ///
  /// In he, this message translates to:
  /// **'טופלו'**
  String get tabDecided;

  /// No description provided for @noPending.
  ///
  /// In he, this message translates to:
  /// **'אף אחד לא ממתין 🎉'**
  String get noPending;

  /// No description provided for @reviewTitle2.
  ///
  /// In he, this message translates to:
  /// **'בדיקת בקשה'**
  String get reviewTitle2;

  /// No description provided for @nameLabel.
  ///
  /// In he, this message translates to:
  /// **'שם'**
  String get nameLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In he, this message translates to:
  /// **'טלפון'**
  String get phoneLabel;

  /// No description provided for @requestedParking.
  ///
  /// In he, this message translates to:
  /// **'חניות מבוקשות'**
  String get requestedParking;

  /// No description provided for @flagSecondResident.
  ///
  /// In he, this message translates to:
  /// **'דייר/ת נוסף/ת באותה דירה'**
  String get flagSecondResident;

  /// No description provided for @flagHeldByOther.
  ///
  /// In he, this message translates to:
  /// **'החניה משויכת כרגע למישהו אחר'**
  String get flagHeldByOther;

  /// No description provided for @flagOwn.
  ///
  /// In he, this message translates to:
  /// **'זו הבקשה שלכם'**
  String get flagOwn;

  /// No description provided for @approveApplication.
  ///
  /// In he, this message translates to:
  /// **'אישור הבקשה'**
  String get approveApplication;

  /// No description provided for @rejectApplication.
  ///
  /// In he, this message translates to:
  /// **'דחיית הבקשה'**
  String get rejectApplication;

  /// No description provided for @requestInfo.
  ///
  /// In he, this message translates to:
  /// **'בקשת מידע נוסף'**
  String get requestInfo;

  /// No description provided for @alsoApproveParking.
  ///
  /// In he, this message translates to:
  /// **'לאשר גם את החניה {space}'**
  String alsoApproveParking(String space);

  /// No description provided for @applicationApproved.
  ///
  /// In he, this message translates to:
  /// **'הבקשה אושרה'**
  String get applicationApproved;

  /// No description provided for @applicationRejected.
  ///
  /// In he, this message translates to:
  /// **'הבקשה נדחתה'**
  String get applicationRejected;

  /// No description provided for @infoRequested.
  ///
  /// In he, this message translates to:
  /// **'נשלחה בקשה למידע נוסף'**
  String get infoRequested;

  /// No description provided for @submittedAgo.
  ///
  /// In he, this message translates to:
  /// **'נשלחה {when}'**
  String submittedAgo(String when);

  /// No description provided for @assignmentsTitle.
  ///
  /// In he, this message translates to:
  /// **'שיוך חניות'**
  String get assignmentsTitle;

  /// No description provided for @tabRequests.
  ///
  /// In he, this message translates to:
  /// **'בקשות'**
  String get tabRequests;

  /// No description provided for @tabActive.
  ///
  /// In he, this message translates to:
  /// **'פעילות'**
  String get tabActive;

  /// No description provided for @heldByOther.
  ///
  /// In he, this message translates to:
  /// **'משויכת כרגע לאחר'**
  String get heldByOther;

  /// No description provided for @endAssignment.
  ///
  /// In he, this message translates to:
  /// **'סיום שיוך'**
  String get endAssignment;

  /// No description provided for @assignmentApproved.
  ///
  /// In he, this message translates to:
  /// **'השיוך אושר'**
  String get assignmentApproved;

  /// No description provided for @assignmentRejected.
  ///
  /// In he, this message translates to:
  /// **'השיוך נדחה'**
  String get assignmentRejected;

  /// No description provided for @residentLabel.
  ///
  /// In he, this message translates to:
  /// **'תושב/ת'**
  String get residentLabel;

  /// No description provided for @disputesTitle.
  ///
  /// In he, this message translates to:
  /// **'מחלוקות'**
  String get disputesTitle;

  /// No description provided for @noDisputes.
  ///
  /// In he, this message translates to:
  /// **'אין מחלוקות 🎉'**
  String get noDisputes;

  /// No description provided for @resolve.
  ///
  /// In he, this message translates to:
  /// **'סגירת מחלוקת'**
  String get resolve;

  /// No description provided for @serviceDelivered.
  ///
  /// In he, this message translates to:
  /// **'האם השירות ניתן?'**
  String get serviceDelivered;

  /// No description provided for @resolutionNote.
  ///
  /// In he, this message translates to:
  /// **'הערה (חובה)'**
  String get resolutionNote;

  /// No description provided for @resolvedChip.
  ///
  /// In he, this message translates to:
  /// **'נסגרה'**
  String get resolvedChip;

  /// No description provided for @openChip.
  ///
  /// In he, this message translates to:
  /// **'פתוחה'**
  String get openChip;

  /// No description provided for @youArePartyNote.
  ///
  /// In he, this message translates to:
  /// **'אתם צד במחלוקת הזו. הסגירה מסומנת ביומן.'**
  String get youArePartyNote;

  /// No description provided for @statsTitle.
  ///
  /// In he, this message translates to:
  /// **'סטטיסטיקה'**
  String get statsTitle;

  /// No description provided for @statApartments.
  ///
  /// In he, this message translates to:
  /// **'דירות'**
  String get statApartments;

  /// No description provided for @statResidents.
  ///
  /// In he, this message translates to:
  /// **'תושבים מאושרים'**
  String get statResidents;

  /// No description provided for @statActiveWeek.
  ///
  /// In he, this message translates to:
  /// **'פעילים השבוע'**
  String get statActiveWeek;

  /// No description provided for @statListings.
  ///
  /// In he, this message translates to:
  /// **'חניות שפורסמו'**
  String get statListings;

  /// No description provided for @statReservations.
  ///
  /// In he, this message translates to:
  /// **'הזמנות חניה'**
  String get statReservations;

  /// No description provided for @statRequests.
  ///
  /// In he, this message translates to:
  /// **'בקשות איסוף'**
  String get statRequests;

  /// No description provided for @statDoneParking.
  ///
  /// In he, this message translates to:
  /// **'עסקאות חניה שהושלמו'**
  String get statDoneParking;

  /// No description provided for @statDonePickup.
  ///
  /// In he, this message translates to:
  /// **'איסופים שהושלמו'**
  String get statDonePickup;

  /// No description provided for @statCompletion.
  ///
  /// In he, this message translates to:
  /// **'שיעור השלמה'**
  String get statCompletion;

  /// No description provided for @statRating.
  ///
  /// In he, this message translates to:
  /// **'דירוג ממוצע'**
  String get statRating;

  /// No description provided for @activityTitle.
  ///
  /// In he, this message translates to:
  /// **'פעילות בבניין'**
  String get activityTitle;

  /// No description provided for @tabListings.
  ///
  /// In he, this message translates to:
  /// **'חניות'**
  String get tabListings;

  /// No description provided for @tabPackages.
  ///
  /// In he, this message translates to:
  /// **'חבילות'**
  String get tabPackages;

  /// No description provided for @tabTransactions.
  ///
  /// In he, this message translates to:
  /// **'עסקאות'**
  String get tabTransactions;

  /// No description provided for @joinCodeTitle.
  ///
  /// In he, this message translates to:
  /// **'קוד הצטרפות'**
  String get joinCodeTitle;

  /// No description provided for @joinCodeHint.
  ///
  /// In he, this message translates to:
  /// **'שתפו את הקוד עם השכנים. הקוד רק מזהה את הבניין — האישור שלכם הוא ההגנה.'**
  String get joinCodeHint;

  /// No description provided for @rotateCode.
  ///
  /// In he, this message translates to:
  /// **'החלפת קוד'**
  String get rotateCode;

  /// No description provided for @posterTitle.
  ///
  /// In he, this message translates to:
  /// **'כרזה להדפסה'**
  String get posterTitle;

  /// No description provided for @posterBody.
  ///
  /// In he, this message translates to:
  /// **'סרקו או הקלידו את הקוד כדי להצטרף ל{building}'**
  String posterBody(String building);

  /// No description provided for @selfReviewSwitch.
  ///
  /// In he, this message translates to:
  /// **'אישור עצמי של המנהל'**
  String get selfReviewSwitch;

  /// No description provided for @selfReviewHint.
  ///
  /// In he, this message translates to:
  /// **'מאפשר לכם לאשר את הבקשות של עצמכם כל עוד אתם המנהל/ת היחיד/ה'**
  String get selfReviewHint;

  /// No description provided for @buildingInfo.
  ///
  /// In he, this message translates to:
  /// **'פרטי הבניין'**
  String get buildingInfo;

  /// No description provided for @apartmentsCount.
  ///
  /// In he, this message translates to:
  /// **'{n} דירות'**
  String apartmentsCount(String n);

  /// No description provided for @spacesCount.
  ///
  /// In he, this message translates to:
  /// **'{n} חניות'**
  String spacesCount(String n);

  /// No description provided for @platformTitle.
  ///
  /// In he, this message translates to:
  /// **'ניהול פלטפורמה'**
  String get platformTitle;

  /// No description provided for @buildingsTitle.
  ///
  /// In he, this message translates to:
  /// **'בניינים'**
  String get buildingsTitle;

  /// No description provided for @createBuilding.
  ///
  /// In he, this message translates to:
  /// **'יצירת בניין'**
  String get createBuilding;

  /// No description provided for @bDraft.
  ///
  /// In he, this message translates to:
  /// **'טיוטה'**
  String get bDraft;

  /// No description provided for @bActive.
  ///
  /// In he, this message translates to:
  /// **'פעיל'**
  String get bActive;

  /// No description provided for @bSuspended.
  ///
  /// In he, this message translates to:
  /// **'מושעה'**
  String get bSuspended;

  /// No description provided for @stepDetails.
  ///
  /// In he, this message translates to:
  /// **'פרטים'**
  String get stepDetails;

  /// No description provided for @stepApartments.
  ///
  /// In he, this message translates to:
  /// **'דירות'**
  String get stepApartments;

  /// No description provided for @stepParking.
  ///
  /// In he, this message translates to:
  /// **'חניות'**
  String get stepParking;

  /// No description provided for @stepReview.
  ///
  /// In he, this message translates to:
  /// **'סיכום'**
  String get stepReview;

  /// No description provided for @buildingName.
  ///
  /// In he, this message translates to:
  /// **'שם הבניין'**
  String get buildingName;

  /// No description provided for @buildingAddress.
  ///
  /// In he, this message translates to:
  /// **'כתובת מלאה'**
  String get buildingAddress;

  /// No description provided for @cityLabel.
  ///
  /// In he, this message translates to:
  /// **'עיר'**
  String get cityLabel;

  /// No description provided for @apartmentCount.
  ///
  /// In he, this message translates to:
  /// **'מספר דירות'**
  String get apartmentCount;

  /// No description provided for @parkingCount.
  ///
  /// In he, this message translates to:
  /// **'מספר חניות'**
  String get parkingCount;

  /// No description provided for @rangeGenerator.
  ///
  /// In he, this message translates to:
  /// **'יצירה לפי טווח'**
  String get rangeGenerator;

  /// No description provided for @rangeApartmentsHint.
  ///
  /// In he, this message translates to:
  /// **'קומות 1–6, 4 דירות בקומה → 101…604'**
  String get rangeApartmentsHint;

  /// No description provided for @rangeParkingHint.
  ///
  /// In he, this message translates to:
  /// **'P01–P24'**
  String get rangeParkingHint;

  /// No description provided for @pasteList.
  ///
  /// In he, this message translates to:
  /// **'הדבקת רשימה'**
  String get pasteList;

  /// No description provided for @previewLabel.
  ///
  /// In he, this message translates to:
  /// **'תצוגה מקדימה'**
  String get previewLabel;

  /// No description provided for @countMatch.
  ///
  /// In he, this message translates to:
  /// **'{have} מתוך {want} ✓'**
  String countMatch(String have, String want);

  /// No description provided for @checklistTitle.
  ///
  /// In he, this message translates to:
  /// **'רשימת בדיקה להפעלה'**
  String get checklistTitle;

  /// No description provided for @chkApartments.
  ///
  /// In he, this message translates to:
  /// **'רשימת דירות'**
  String get chkApartments;

  /// No description provided for @chkSpaces.
  ///
  /// In he, this message translates to:
  /// **'רשימת חניות'**
  String get chkSpaces;

  /// No description provided for @chkCounts.
  ///
  /// In he, this message translates to:
  /// **'המספרים תואמים'**
  String get chkCounts;

  /// No description provided for @chkAgreement.
  ///
  /// In he, this message translates to:
  /// **'הסכם בניין (נוסח זמני)'**
  String get chkAgreement;

  /// No description provided for @acceptActivate.
  ///
  /// In he, this message translates to:
  /// **'אישור ההסכם והפעלת הבניין'**
  String get acceptActivate;

  /// No description provided for @buildingActivated.
  ///
  /// In he, this message translates to:
  /// **'הבניין הופעל'**
  String get buildingActivated;

  /// No description provided for @suspend.
  ///
  /// In he, this message translates to:
  /// **'השעיה'**
  String get suspend;

  /// No description provided for @reactivate.
  ///
  /// In he, this message translates to:
  /// **'הפעלה מחדש'**
  String get reactivate;

  /// No description provided for @noAdminAppointNote.
  ///
  /// In he, this message translates to:
  /// **'אתם מנהל/ת הבניין באופן אוטומטי. אין צורך למנות מנהלים.'**
  String get noAdminAppointNote;

  /// No description provided for @demoAcceptOffer.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: {name} מאשר/ת את ההצעה שלי'**
  String demoAcceptOffer(String name);

  /// No description provided for @demoEnterCode.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: השכן מזין את הקוד שלכם'**
  String get demoEnterCode;

  /// No description provided for @demoConfirmReceived.
  ///
  /// In he, this message translates to:
  /// **'הדגמה: {name} מאשר/ת קבלה'**
  String demoConfirmReceived(String name);
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'he':
      return AppL10nHe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
