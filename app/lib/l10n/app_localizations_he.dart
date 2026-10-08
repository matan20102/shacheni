// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppL10nHe extends AppL10n {
  AppL10nHe([String locale = 'he']) : super(locale);

  @override
  String get appName => 'שכני';

  @override
  String get cancel => 'ביטול';

  @override
  String get confirm => 'אישור';

  @override
  String get save => 'שמירה';

  @override
  String get continueLabel => 'המשך';

  @override
  String get back => 'חזרה';

  @override
  String get close => 'סגירה';

  @override
  String get done => 'סיום';

  @override
  String get retry => 'נסו שוב';

  @override
  String get seeAll => 'הכול';

  @override
  String get send => 'שליחה';

  @override
  String get submit => 'שליחה';

  @override
  String get edit => 'עריכה';

  @override
  String get yes => 'כן';

  @override
  String get no => 'לא';

  @override
  String get optional => 'אופציונלי';

  @override
  String get today => 'היום';

  @override
  String get tomorrow => 'מחר';

  @override
  String get now => 'עכשיו';

  @override
  String get free => 'חינם';

  @override
  String get accept => 'אישור';

  @override
  String get decline => 'דחייה';

  @override
  String get approve => 'אישור';

  @override
  String get reject => 'דחייה';

  @override
  String get loadError => 'לא הצלחנו לטעון';

  @override
  String get copy => 'העתקה';

  @override
  String get copied => 'הועתק';

  @override
  String get call => 'התקשרות';

  @override
  String get whatsapp => 'וואטסאפ';

  @override
  String get youLabel => 'אתם';

  @override
  String verifiedResident(String building) {
    return 'תושב/ת מאומת/ת של $building';
  }

  @override
  String get newNeighbor => 'שכן/ה חדש/ה';

  @override
  String completedCount(String n) {
    return '$n עסקאות הושלמו';
  }

  @override
  String memberSince(String year) {
    return 'חבר/ה מאז $year';
  }

  @override
  String inHM(String h, String m) {
    return 'בעוד $h שע׳ $m דק׳';
  }

  @override
  String inM(String m) {
    return 'בעוד $m דק׳';
  }

  @override
  String get overdue => 'עבר הזמן';

  @override
  String untilTime(String time) {
    return 'עד $time';
  }

  @override
  String dayAtTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String windowSame(String day, String from, String to) {
    return '$day · $from–$to';
  }

  @override
  String windowDiff(String from, String to) {
    return '$from – $to';
  }

  @override
  String priceShekel(String amount) {
    return '₪$amount';
  }

  @override
  String get navHome => 'בית';

  @override
  String get navParking => 'חניה';

  @override
  String get navPackages => 'חבילות';

  @override
  String get navMe => 'אני';

  @override
  String get notificationsTooltip => 'התראות';

  @override
  String get paymentNotice =>
      'התשלום מתבצע ישירות בין השכנים (מזומן, ביט, פייבוקס…). האפליקציה לא מעבדת ולא מחזיקה כסף.';

  @override
  String get demoBadge => 'הדגמה';

  @override
  String get demoNote => 'זהו אב־טיפוס עם נתוני דוגמה. שום דבר לא נשמר בשרת.';

  @override
  String get statusCompleted => 'הושלם';

  @override
  String get statusCancelled => 'בוטל';

  @override
  String get statusExpired => 'פג תוקף';

  @override
  String get statusDeclined => 'נדחה';

  @override
  String get statusActive => 'פעיל';

  @override
  String get statusAvailable => 'פנויה';

  @override
  String get statusReserved => 'שמורה';

  @override
  String get welcomeTitle => 'חניה, עזרה הדדית, והכול בבניין שלכם';

  @override
  String get welcomeBullet1 => 'שתפו חניה פנויה עם השכנים';

  @override
  String get welcomeBullet2 => 'בקשו או הציעו איסוף חבילה';

  @override
  String get welcomeBullet3 => 'רק תושבים מאומתים. הפרטיות שלכם קודם.';

  @override
  String get getStarted => 'התחלה';

  @override
  String get skipToDemo => 'דלגו להדגמה (ללא הרשמה)';

  @override
  String get phoneTitle => 'מה מספר הטלפון שלכם?';

  @override
  String get phoneSubtitle => 'נשלח אליכם קוד אימות ב־SMS';

  @override
  String get sendCode => 'שלחו קוד';

  @override
  String get phoneInvalid => 'מספר הטלפון לא תקין';

  @override
  String get otpTitle => 'הקלידו את הקוד';

  @override
  String otpSubtitle(String phone) {
    return 'שלחנו קוד אל $phone';
  }

  @override
  String get otpChange => 'החלפת מספר';

  @override
  String get otpResend => 'שליחה חוזרת';

  @override
  String otpResendIn(String s) {
    return 'שליחה חוזרת בעוד $s שנ׳';
  }

  @override
  String get verify => 'אימות';

  @override
  String get otpDemoHint => 'בהדגמה כל קוד עובד (למשל 123456)';

  @override
  String get legalTitle => 'לפני שממשיכים';

  @override
  String get legalSubtitle => 'קראו ואשרו את המסמכים הבאים';

  @override
  String get termsOfService => 'תנאי שימוש';

  @override
  String get privacyPolicy => 'מדיניות פרטיות';

  @override
  String get communityRules => 'כללי הקהילה';

  @override
  String get residentDeclaration => 'הצהרת תושב';

  @override
  String get buildingAgreement => 'הסכם בניין';

  @override
  String legalVersion(String version) {
    return 'גרסה $version';
  }

  @override
  String get legalRead => 'קריאה';

  @override
  String get legalAccept => 'קראתי ואני מאשר/ת';

  @override
  String get legalPlaceholderNote =>
      'מסמך זמני: הנוסח המשפטי המלא יפורסם על ידי בעל האפליקציה.';

  @override
  String get legalAcceptContinue => 'אישור והמשך';

  @override
  String get joinTitle => 'באיזה בניין אתם גרים?';

  @override
  String get joinSubtitle => 'הקלידו את קוד הבניין שקיבלתם מהמנהל';

  @override
  String get joinCodeLabel => 'קוד בניין';

  @override
  String get joinFind => 'חיפוש בניין';

  @override
  String get joinFound => 'מצאנו את הבניין:';

  @override
  String get joinConfirm => 'כן, זה הבניין שלי';

  @override
  String get joinInvalid => 'הקוד לא תקין';

  @override
  String joinDemoHint(String code) {
    return 'קוד להדגמה: $code';
  }

  @override
  String get applyTitle => 'בקשת הצטרפות';

  @override
  String get applySubtitle => 'מנהל הבניין יאמת שאתם גרים כאן';

  @override
  String get fullName => 'שם מלא';

  @override
  String get apartment => 'דירה';

  @override
  String get apartmentPick => 'בחרו דירה';

  @override
  String get parkingSpaces => 'חניות';

  @override
  String get parkingOptionalHint => 'אם יש לכם חניה פרטית, בחרו אותה מהרשימה';

  @override
  String get noParking => 'אין לי חניה פרטית';

  @override
  String get declarationsTitle => 'הצהרות';

  @override
  String get decl1 => 'המידע שמסרתי נכון';

  @override
  String get decl2 => 'אני תושב/ת הבניין';

  @override
  String get decl3 => 'פרטי הדירה נכונים';

  @override
  String get decl4 => 'פרטי החניה נכונים';

  @override
  String get decl5 => 'הבנתי את כללי הקהילה';

  @override
  String get submitRequest => 'שליחת בקשה';

  @override
  String get optionalPhoto => 'תמונת פרופיל (אופציונלי)';

  @override
  String get fieldRequired => 'שדה חובה';

  @override
  String pendingTitle(String building) {
    return 'מאמתים שאתם גרים ב$building';
  }

  @override
  String get pendingBody => 'בדרך כלל זה לוקח עד יום. נשלח התראה כשתאושרו.';

  @override
  String get pendingSummary => 'הפרטים ששלחתם';

  @override
  String get pendingDemoApprove => 'הדגמה: אשרו אותי כמנהל';

  @override
  String get withdrawRequest => 'ביטול הבקשה';

  @override
  String get logOut => 'התנתקות';

  @override
  String homeGreeting(String name) {
    return 'שלום $name 👋';
  }

  @override
  String get homeQuestion => 'מה אפשר לעשות בבניין עכשיו?';

  @override
  String get qaFindParking => 'מצאו חניה';

  @override
  String get qaShareParking => 'שתפו את החניה שלי';

  @override
  String get qaRequestPickup => 'בקשו איסוף חבילה';

  @override
  String get qaHelp => 'עזרו לשכן';

  @override
  String get needsAction => 'דורש את תשומת ליבכם';

  @override
  String get happeningSoon => 'בקרוב';

  @override
  String get parkingNow => 'חניות פנויות';

  @override
  String get pickupNeighbors => 'שכנים שצריכים איסוף';

  @override
  String get nothingYet => 'עוד אין פעילות בבניין';

  @override
  String get beFirst => 'היו הראשונים לשתף חניה או לבקש עזרה';

  @override
  String actRespondRequest(String name, String space) {
    return '$name ביקש/ה את חניה $space';
  }

  @override
  String actConfirmReservation(String space) {
    return 'אשרו את ההזמנה של חניה $space';
  }

  @override
  String get actShowCode => 'הראו לשכן את קוד המסירה';

  @override
  String actHelperArrived(String name) {
    return '$name הגיע/ה עם החבילה';
  }

  @override
  String get actViewPhoto => 'החבילה הושארה ליד הדלת — צפו בתמונה';

  @override
  String actPayPay(String amount, String name) {
    return 'סמנו ששילמתם ₪$amount ל$name';
  }

  @override
  String actPayReceived(String amount, String name) {
    return '$name אומר/ת ששילם/ה ₪$amount';
  }

  @override
  String actRate(String name) {
    return 'דרגו את $name';
  }

  @override
  String actOfferReceived(String name) {
    return '$name הציע/ה לאסוף את החבילה';
  }

  @override
  String actHelperJob(String name) {
    return 'איסוף עבור $name';
  }

  @override
  String soonReservation(String space, String window) {
    return 'חניה $space · $window';
  }

  @override
  String soonJob(String place) {
    return 'איסוף: $place';
  }

  @override
  String get parkingTitle => 'חניה';

  @override
  String get segFind => 'חיפוש';

  @override
  String get segMine => 'שלי';

  @override
  String get segSharing => 'שיתוף';

  @override
  String get segRenting => 'שכירות';

  @override
  String get whenNeedParking => 'מתי צריך חניה?';

  @override
  String get presetTonight => 'הערב';

  @override
  String get presetTomorrow => 'מחר';

  @override
  String get presetWeek => 'השבוע';

  @override
  String get fromLabel => 'מ־';

  @override
  String get toLabel => 'עד';

  @override
  String get showAllUpcoming => 'הצגת כל הקרובות';

  @override
  String get coversYourTime => 'מכסה את הזמן שלכם';

  @override
  String get instantBadge => 'הזמנה מיידית';

  @override
  String get approvalBadge => 'באישור בעל החניה';

  @override
  String get noSpacesTitle => 'אין חניות פנויות בזמנים האלה';

  @override
  String get noSpacesMsg => 'נסו להרחיב את הטווח או להציג את כל הקרובות';

  @override
  String parkingLabel(String space) {
    return 'חניה $space';
  }

  @override
  String get listingDetailTitle => 'פרטי החניה';

  @override
  String get requestAction => 'שליחת בקשה';

  @override
  String get reserveNow => 'הזמינו עכשיו';

  @override
  String get ownListing => 'זו החניה שלכם';

  @override
  String get offeredBy => 'מוצעת על ידי';

  @override
  String get whenLabel => 'מתי';

  @override
  String get priceLabel => 'מחיר';

  @override
  String get descriptionLabel => 'תיאור';

  @override
  String get reviewTitle => 'סקירה ושליחה';

  @override
  String get vehiclePlate => 'מספר רכב (אופציונלי)';

  @override
  String get noteToOwner => 'הערה לבעל החניה';

  @override
  String get sendRequest => 'שליחת בקשה';

  @override
  String get requestSentSnack => 'הבקשה נשלחה לבעל החניה';

  @override
  String get reservedSnack => 'החניה הוזמנה';

  @override
  String get slotTaken => 'מישהו הקדים אתכם והחניה כבר נתפסה';

  @override
  String get publishTitle => 'שיתוף חניה';

  @override
  String get chooseSpace => 'בחרו חניה';

  @override
  String get startsLabel => 'מתחילה';

  @override
  String get endsLabel => 'מסתיימת';

  @override
  String get priceInput => 'מחיר (₪)';

  @override
  String get descriptionOptional => 'תיאור (אופציונלי)';

  @override
  String get approveEach => 'אני מאשר/ת כל בקשה';

  @override
  String get approveEachHint => 'כשהאפשרות כבויה — ההזמנה מיידית';

  @override
  String get publish => 'פרסום';

  @override
  String get publishedSnack => 'החניה פורסמה';

  @override
  String get noAssignmentTitle => 'אין חניה משויכת אליכם';

  @override
  String get noAssignmentMsg =>
      'כדי לשתף חניה, בקשו שיוך חניה והמנהל יאמת אותה';

  @override
  String get requestAssignmentBtn => 'בקשת שיוך חניה';

  @override
  String get overlapError => 'כבר פרסמתם את החניה הזו בזמן הזה';

  @override
  String get invalidWindow => 'זמן הסיום חייב להיות אחרי ההתחלה';

  @override
  String get needsResponse => 'ממתין לתגובה';

  @override
  String get upcoming => 'קרוב';

  @override
  String get past => 'עבר';

  @override
  String get emptySharing => 'עוד לא שיתפתם חניה';

  @override
  String get emptyRenting => 'אין לכם הזמנות חניה';

  @override
  String get requestsTitle => 'בקשות';

  @override
  String get noRequestsYet => 'עדיין אין בקשות. החניה שלכם גלויה לשכנים.';

  @override
  String get cancelAvailability => 'ביטול הזמינות';

  @override
  String get cancelAvailabilityBody =>
      'בקשות שממתינות יידחו והשכנים יקבלו הודעה.';

  @override
  String get acceptWarn => 'אישור בקשה ידחה את שאר הבקשות לאותו זמן.';

  @override
  String get resRequested => 'ממתין לאישור';

  @override
  String get resAccepted => 'אושר — נדרש אישור סופי';

  @override
  String get resConfirmed => 'הוזמן';

  @override
  String get resActive => 'פעיל';

  @override
  String get resCompleted => 'הסתיים';

  @override
  String get stepRequested => 'בקשה';

  @override
  String get stepAccepted => 'אושר';

  @override
  String get stepConfirmed => 'הוזמן';

  @override
  String get stepActive => 'פעיל';

  @override
  String get stepEnded => 'הסתיים';

  @override
  String get reservationTitle => 'פרטי הזמנה';

  @override
  String get confirmReservation => 'אישור הזמנה';

  @override
  String confirmBy(String time) {
    return 'יש לאשר עד $time';
  }

  @override
  String confirmSheetBody(String name) {
    return 'התשלום מתבצע ישירות בינכם ל$name. האפליקציה לא מעבדת ולא מחזיקה כסף.';
  }

  @override
  String get contactAfter => 'פרטי הקשר יופיעו אחרי אישור סופי';

  @override
  String get vehicleLabel => 'רכב';

  @override
  String get noteLabel => 'הערה';

  @override
  String demoAcceptReq(String name) {
    return 'הדגמה: $name מאשר/ת את הבקשה';
  }

  @override
  String get demoEndBooking => 'הדגמה: זמן ההזמנה הסתיים';

  @override
  String get mySpacesTitle => 'החניות שלי';

  @override
  String get assignActive => 'מאומתת';

  @override
  String get assignRequested => 'ממתינה לאימות';

  @override
  String get assignRejected => 'נדחתה';

  @override
  String get assignEnded => 'הסתיימה';

  @override
  String get withdrawRequestShort => 'ביטול בקשה';

  @override
  String get noSpacesLinked => 'אין חניות משויכות אליכם';

  @override
  String get requestAssignTitle => 'בקשת שיוך חניה';

  @override
  String get assignHint =>
      'המנהל יוודא שהחניה באמת שלכם לפני ששייך אותה אליכם.';

  @override
  String get pickSpace => 'בחרו חניה מהרשימה';

  @override
  String get sendAssignRequest => 'שליחת בקשה למנהל';

  @override
  String get assignSentSnack => 'הבקשה נשלחה למנהל';

  @override
  String get cancelBookingTitle => 'ביטול הזמנה';

  @override
  String get pkgTitle => 'חבילות';

  @override
  String get segHelp => 'עזרה';

  @override
  String get segMyRequests => 'הבקשות שלי';

  @override
  String get segMyOffers => 'ההצעות שלי';

  @override
  String get filterToday => 'היום';

  @override
  String get filterReward => 'תגמול גבוה';

  @override
  String get rewardLabel => 'תגמול';

  @override
  String get doorOkBadge => 'אפשר להשאיר ליד הדלת';

  @override
  String get noRequestsTitle => 'אף אחד לא צריך איסוף כרגע 🎉';

  @override
  String get noRequestsMsg => 'יש לכם משהו לאסוף? בקשו משכן.';

  @override
  String get newPickupTitle => 'בקשת איסוף חבילה';

  @override
  String get pickupLocation => 'מיקום האיסוף';

  @override
  String get pickupLocationHint => 'למשל: קניון עזריאלי';

  @override
  String get pkgDescription => 'תיאור החבילה';

  @override
  String get pkgDescriptionHint => 'קופסה קטנה, כ־1 ק״ג';

  @override
  String get deadlineLabel => 'עד מתי';

  @override
  String get rewardChoose => 'תגמול';

  @override
  String get notesLabel => 'הערות';

  @override
  String get pickupRef => 'מספר הזמנה / קוד איסוף';

  @override
  String get pickupRefHint => 'פרטי — יישלח רק לשכן שתבחרו';

  @override
  String get handoffPlace => 'מקום המסירה';

  @override
  String get defaultLobby => 'לובי הבניין';

  @override
  String get doorToggle => 'אפשר להשאיר את החבילה ליד דלת הדירה';

  @override
  String get doorToggleHint => 'השכן חייב לשלוח לכם תמונה כהוכחה';

  @override
  String get ackProhibited =>
      'אין בחבילה פריטים אסורים (מזומן, מסמכים מזהים, תרופות…)';

  @override
  String get ackThirdParty => 'נקודת האיסוף מאפשרת לאסוף עבורי';

  @override
  String get postRequest => 'פרסום הבקשה';

  @override
  String get postedSnack => 'הבקשה פורסמה';

  @override
  String get deadlineTooSoon => 'הדד־ליין חייב להיות לפחות 30 דקות קדימה';

  @override
  String get offerToPickup => 'אני אאסוף';

  @override
  String get withdrawOffer => 'ביטול ההצעה';

  @override
  String get offerSheetTitle => 'הצעת איסוף';

  @override
  String get plannedTime => 'מתי תגיעו לשם? (אופציונלי)';

  @override
  String get messageOptional => 'הודעה (אופציונלי)';

  @override
  String get sendOffer => 'שליחת הצעה';

  @override
  String get offerSentSnack => 'ההצעה נשלחה';

  @override
  String get offerPending => 'ההצעה שלכם נשלחה וממתינה לאישור';

  @override
  String get hiddenDetails =>
      'מספר הדירה ופרטי האיסוף יופיעו אחרי שההצעה שלכם תאושר.';

  @override
  String get reqOpen => 'פתוחה';

  @override
  String get reqOffers => 'התקבלו הצעות';

  @override
  String get reqAccepted => 'ההצעה אושרה';

  @override
  String get reqCollected => 'נאסף';

  @override
  String get reqDelivered => 'נמסר';

  @override
  String get reqCompleted => 'הושלם';

  @override
  String get reqCancelled => 'בוטל';

  @override
  String get reqExpired => 'פג תוקף';

  @override
  String get reqDisputed => 'בבדיקה';

  @override
  String get stOpen => 'פתוח';

  @override
  String get stOffers => 'הצעות';

  @override
  String get stAccepted => 'אושר';

  @override
  String get stCollected => 'נאסף';

  @override
  String get stDelivered => 'נמסר';

  @override
  String get stCompleted => 'הושלם';

  @override
  String get offersTitle => 'הצעות';

  @override
  String get noOffersYet => 'השכנים קיבלו הודעה. נעדכן כשמישהו יציע לאסוף.';

  @override
  String offerAt(String time) {
    return 'יגיע בסביבות $time';
  }

  @override
  String get yourHelper => 'השכן/ה שאוסף/ת';

  @override
  String get codePanelTitle => 'קוד המסירה שלכם';

  @override
  String get codeHint => 'אמרו את הקוד רק כשהחבילה בידיכם';

  @override
  String get regenerateCode => 'יצירת קוד חדש';

  @override
  String regenLeft(String n) {
    return 'נותרו $n';
  }

  @override
  String get allowDoor => 'אפשרו להשאיר ליד הדלת';

  @override
  String get doorAllowedNote => 'מאושר — השכן יצרף תמונה כהוכחה';

  @override
  String arrivalBanner(String name) {
    return '$name הגיע/ה עם החבילה';
  }

  @override
  String get deliveryPhoto => 'תמונת מסירה';

  @override
  String photoTakenAt(String name, String time) {
    return 'צולם $time על ידי $name';
  }

  @override
  String get confirmReceived => 'אישור קבלה';

  @override
  String get reportProblem => 'דיווח על בעיה';

  @override
  String autoConfirmNote(String time) {
    return 'ללא תגובה, יאושר אוטומטית בעוד $time';
  }

  @override
  String get cancelRequestBtn => 'ביטול הבקשה';

  @override
  String get jobTitle => 'משימת איסוף';

  @override
  String get pickupBlock => 'איסוף';

  @override
  String get deliverTo => 'מסירה';

  @override
  String apartmentLabel(String apt) {
    return 'דירה $apt';
  }

  @override
  String get pickupRefLabel => 'מספר איסוף';

  @override
  String get iPickedUp => 'אספתי את החבילה';

  @override
  String get imHere => 'הגעתי';

  @override
  String arrivalSent(String name) {
    return 'הודענו ל$name שהגעתם';
  }

  @override
  String get enterCode => 'הזנת קוד מסירה';

  @override
  String get cantHandOver => 'לא מצליחים למסור?';

  @override
  String get withdrawJob => 'ביטול המשימה';

  @override
  String get codeEntryTitle => 'קוד מסירה';

  @override
  String codeEntryHint(String name) {
    return 'בקשו מ$name את הקוד בן 4 הספרות';
  }

  @override
  String get confirmDelivery => 'אישור מסירה';

  @override
  String wrongCode(String n) {
    return 'הקוד לא תואם. נותרו $n ניסיונות.';
  }

  @override
  String lockedCode(String time) {
    return 'יותר מדי ניסיונות. נסו שוב בעוד $time.';
  }

  @override
  String get deliveredTitle => 'נמסר! 🎉';

  @override
  String get deliveredBody => 'המסירה אושרה. עכשיו נשאר להסדיר את התשלום.';

  @override
  String get methodsTitle => 'איך מוסרים?';

  @override
  String get methodPhone => 'קבלו את הקוד בטלפון';

  @override
  String get methodPhoneHint => 'המבקש מקריא לכם את הקוד גם אם הוא לא בבית';

  @override
  String get methodDoor => 'השאירו ליד דלת הדירה';

  @override
  String get methodDoorHint => 'דורש אישור של המבקש ותמונת הוכחה';

  @override
  String askAllow(String name) {
    return 'בקשו מ$name לאשר';
  }

  @override
  String allowAsked(String name) {
    return 'ביקשנו מ$name לאשר מסירה ליד הדלת';
  }

  @override
  String get methodUnreachable => 'אי אפשר ליצור קשר';

  @override
  String get methodUnreachableHint => 'החבילה נשארת אצלכם והמקרה עובר לבדיקה';

  @override
  String get allowSheetTitle => 'השכן כאן עם החבילה';

  @override
  String get allowSheetBody =>
      'אפשר לרדת לקבל, להקריא את הקוד, או לאשר להשאיר את החבילה ליד הדלת. תקבלו תמונה כהוכחה.';

  @override
  String get showMyCode => 'הציגו את הקוד שלי';

  @override
  String get allowLeaving => 'אפשרו להשאיר ליד הדלת';

  @override
  String get illComeDown => 'אני יורד/ת';

  @override
  String get doorPhotoTitle => 'מסירה ליד הדלת';

  @override
  String get doorPhotoGuide =>
      'צלמו את החבילה ליד הדלת. הימנעו מצילום אנשים ודלתות של שכנים אחרים.';

  @override
  String get takePhoto => 'צילום';

  @override
  String get retake => 'צילום מחדש';

  @override
  String get submitDelivery => 'שליחת המסירה';

  @override
  String get doorPhotoSuccess => 'נמסר — הבקשה עודכנה';

  @override
  String get cameraDemoHint => 'בהדגמה מוצגת תמונת דוגמה במקום מצלמה';

  @override
  String get photoViewerTitle => 'תמונת מסירה';

  @override
  String get photoSample => 'תמונה לדוגמה';

  @override
  String photoMeta(String name, String time) {
    return 'צולם $time · הועלה על ידי $name';
  }

  @override
  String photoNote(String note) {
    return 'הערת השליח: $note';
  }

  @override
  String get photoRetention => 'התמונה נשמרת 30 ימים';

  @override
  String get demoOffer => 'הדגמה: שכן מציע לאסוף';

  @override
  String get demoCollected => 'הדגמה: השכן אסף את החבילה';

  @override
  String get demoArrival => 'הדגמה: השכן הגיע עם החבילה';

  @override
  String get demoDoorDelivery => 'הדגמה: השכן השאיר ליד הדלת עם תמונה';

  @override
  String get payTitle => 'תשלום';

  @override
  String get iPaid => 'אני שילמתי';

  @override
  String waitingConfirm(String name) {
    return 'ממתינים ש$name יאשר/תאשר';
  }

  @override
  String waitingPay(String name) {
    return 'ממתינים ש$name ישלם/תשלם';
  }

  @override
  String saidPaid(String amount, String name) {
    return '$name אומר/ת ששילם/ה ₪$amount';
  }

  @override
  String get paymentReceived => 'התשלום התקבל';

  @override
  String get notReceived => 'לא התקבל';

  @override
  String get noPaymentNeeded => 'אין צורך בתשלום';

  @override
  String get settledLabel => 'התשלום הושלם';

  @override
  String get paymentCancelled => 'התשלום בוטל';

  @override
  String youPayTo(String amount, String name) {
    return 'אתם משלמים ₪$amount ל$name';
  }

  @override
  String youReceiveFrom(String amount, String name) {
    return 'אתם מקבלים ₪$amount מ$name';
  }

  @override
  String get payPending => 'ממתין לתשלום';

  @override
  String get payConfirmed => 'סומן כשולם';

  @override
  String get paySettled => 'שולם';

  @override
  String get payCancelled => 'בוטל';

  @override
  String demoPayerPaid(String name) {
    return 'הדגמה: $name מסמן/ת ששילם/ה';
  }

  @override
  String demoPayeeConfirm(String name) {
    return 'הדגמה: $name מאשר/ת קבלת תשלום';
  }

  @override
  String get txDetailTitle => 'פרטי עסקה';

  @override
  String get txInProgress => 'בתהליך';

  @override
  String get txAwaiting => 'ממתינה לאישור תשלום';

  @override
  String get txCompleted => 'הושלמה';

  @override
  String get txCancelled => 'בוטלה';

  @override
  String get txDisputed => 'בבדיקה';

  @override
  String get youPaid => 'שילמתם';

  @override
  String get youReceived => 'קיבלתם';

  @override
  String get refundRecord => 'נוצרה רשומת החזר נפרדת';

  @override
  String get paymentTimeline => 'ציר תשלום';

  @override
  String get counterparty => 'הצד השני';

  @override
  String get txTypeParking => 'חניה';

  @override
  String get txTypePickup => 'איסוף חבילה';

  @override
  String get historyTitle => 'היסטוריה';

  @override
  String get filterAll => 'הכול';

  @override
  String get filterParking => 'חניה';

  @override
  String get filterPickups => 'איסופים';

  @override
  String get filterPaid => 'שילמתי';

  @override
  String get filterReceived => 'קיבלתי';

  @override
  String get historyEmpty => 'הפעילות שלכם תופיע כאן';

  @override
  String historyTotals(String earned, String paid) {
    return 'שילמתם ₪$paid · קיבלתם ₪$earned';
  }

  @override
  String rateTitle(String name) {
    return 'דרגו את $name';
  }

  @override
  String get rateComment => 'הוסיפו תגובה (אופציונלי)';

  @override
  String get notNow => 'לא עכשיו';

  @override
  String get rateThanks => 'תודה על הדירוג';

  @override
  String get rateHidden =>
      'הדירוגים מופיעים כששני הצדדים דירגו, או אחרי 14 ימים';

  @override
  String get rateButton => 'דירוג';

  @override
  String get alreadyRated => 'כבר דירגתם';

  @override
  String get cancelTitle => 'ביטול';

  @override
  String get consequences => 'מה יקרה:';

  @override
  String get consOther => 'הצד השני יקבל הודעה';

  @override
  String get consRefund => 'אם כבר שולם — תיווצר רשומת החזר נפרדת';

  @override
  String get consCounter => 'הביטול נספר בדירוג האמינות שלכם';

  @override
  String get confirmCancel => 'אישור ביטול';

  @override
  String get keepIt => 'להשאיר';

  @override
  String get cancelledSnack => 'בוטל';

  @override
  String get reportTitle => 'דיווח על בעיה';

  @override
  String get reportReason => 'סיבה';

  @override
  String get rSpaceOccupied => 'החניה הייתה תפוסה';

  @override
  String get rNotDelivered => 'החבילה לא נמסרה';

  @override
  String get rPaymentNotReceived => 'התשלום לא התקבל';

  @override
  String get rUnreachable => 'אי אפשר ליצור קשר עם המבקש';

  @override
  String get rOther => 'אחר';

  @override
  String get reportDesc => 'מה קרה?';

  @override
  String get reportNote =>
      'מנהל הבניין יבדוק תוך 48 שעות, והפעולות האוטומטיות מושהות.';

  @override
  String get submitReport => 'שליחת הדיווח';

  @override
  String get reportSent => 'הדיווח נשלח';

  @override
  String get profileTitle => 'פרופיל שכן';

  @override
  String get reviewsTitle => 'ביקורות';

  @override
  String get noReviews => 'עדיין אין ביקורות';

  @override
  String get privateInfoNote => 'מספר דירה וטלפון לא מוצגים לשכנים';

  @override
  String get notificationsTitle => 'התראות';

  @override
  String get markAllRead => 'סימון הכול כנקרא';

  @override
  String get allCaughtUp => 'הכול מעודכן 🎉';

  @override
  String nParkingRequest(String name, String space) {
    return '$name ביקש/ה את חניה $space';
  }

  @override
  String nParkingAccepted(String name) {
    return '$name אישר/ה — אשרו סופית כדי להזמין';
  }

  @override
  String nOfferReceived(String name) {
    return '$name הציע/ה לאסוף את החבילה שלכם';
  }

  @override
  String nCollected(String name) {
    return '$name אסף/ה את החבילה';
  }

  @override
  String nArrived(String name) {
    return '$name הגיע/ה עם החבילה';
  }

  @override
  String get nDoorDelivered => 'החבילה הושארה ליד הדלת — יש תמונה';

  @override
  String nMarkedPaid(String name) {
    return '$name סימן/ה ששילם/ה';
  }

  @override
  String nRatingRequested(String name) {
    return 'דרגו את $name';
  }

  @override
  String get nApproved => 'אושרתם כתושבי הבניין!';

  @override
  String agoMinutes(String m) {
    return 'לפני $m דק׳';
  }

  @override
  String agoHours(String h) {
    return 'לפני $h שע׳';
  }

  @override
  String agoDays(String d) {
    return 'לפני $d ימים';
  }

  @override
  String get meTitle => 'אני';

  @override
  String apartmentIn(String apt, String building) {
    return 'דירה $apt · $building';
  }

  @override
  String get editProfile => 'עריכת פרופיל';

  @override
  String get settingsTitle => 'הגדרות';

  @override
  String get helpLabel => 'עזרה ויצירת קשר';

  @override
  String get adminArea => 'ניהול הבניין';

  @override
  String get platformArea => 'ניהול פלטפורמה';

  @override
  String get languageLabel => 'שפה';

  @override
  String get hebrew => 'עברית';

  @override
  String get english => 'English';

  @override
  String get notifSettings => 'התראות';

  @override
  String get notifNewPickup => 'בקשות איסוף חדשות';

  @override
  String get notifNewParking => 'חניות חדשות';

  @override
  String get alwaysOn => 'התראות על עסקאות פעילות תמיד';

  @override
  String get legalDocs => 'מסמכים משפטיים';

  @override
  String get appVersion => 'גרסה';

  @override
  String get deleteAccount => 'מחיקת חשבון';

  @override
  String get deleteBlocked => 'אי אפשר למחוק חשבון כשיש עסקאות פעילות';

  @override
  String get showDemoTools => 'הצגת כפתורי הדגמה';

  @override
  String get demoSection => 'הדגמה';

  @override
  String get resetDemo => 'איפוס נתוני ההדגמה';

  @override
  String get serverStatus => 'שרת';

  @override
  String get serverConnected => 'מחובר ל-Supabase';

  @override
  String get serverNotConfigured => 'לא מוגדר — נתוני הדגמה בלבד';

  @override
  String get serverUnreachable => 'אין חיבור לשרת';

  @override
  String get profileEditNote =>
      'שינוי דירה שולח בקשת הצטרפות חדשה לאישור המנהל.';

  @override
  String get adminTitle => 'ניהול הבניין';

  @override
  String get adminHello => 'שלום, מנהל/ת הבניין';

  @override
  String get adminPendingApps => 'בקשות הצטרפות';

  @override
  String get adminParkingRequests => 'בקשות שיוך חניה';

  @override
  String get adminDisputes => 'מחלוקות';

  @override
  String get adminActivity => 'פעילות בבניין';

  @override
  String get adminStats => 'סטטיסטיקה';

  @override
  String get adminSettings => 'הגדרות בניין';

  @override
  String get adminResidents => 'דיירים';

  @override
  String get adminApartments => 'דירות';

  @override
  String get adminSpaces => 'חניות';

  @override
  String get selfReviewBanner =>
      'כמנהל/ת היחיד/ה אפשר לאשר את עצמכם. הפעולה מסומנת ביומן הביקורת.';

  @override
  String get applicationsTitle => 'בקשות הצטרפות';

  @override
  String get tabPending => 'ממתינות';

  @override
  String get tabDecided => 'טופלו';

  @override
  String get noPending => 'אף אחד לא ממתין 🎉';

  @override
  String get reviewTitle2 => 'בדיקת בקשה';

  @override
  String get nameLabel => 'שם';

  @override
  String get phoneLabel => 'טלפון';

  @override
  String get requestedParking => 'חניות מבוקשות';

  @override
  String get flagSecondResident => 'דייר/ת נוסף/ת באותה דירה';

  @override
  String get flagHeldByOther => 'החניה משויכת כרגע למישהו אחר';

  @override
  String get flagOwn => 'זו הבקשה שלכם';

  @override
  String get approveApplication => 'אישור הבקשה';

  @override
  String get rejectApplication => 'דחיית הבקשה';

  @override
  String get requestInfo => 'בקשת מידע נוסף';

  @override
  String alsoApproveParking(String space) {
    return 'לאשר גם את החניה $space';
  }

  @override
  String get applicationApproved => 'הבקשה אושרה';

  @override
  String get applicationRejected => 'הבקשה נדחתה';

  @override
  String get infoRequested => 'נשלחה בקשה למידע נוסף';

  @override
  String submittedAgo(String when) {
    return 'נשלחה $when';
  }

  @override
  String get assignmentsTitle => 'שיוך חניות';

  @override
  String get tabRequests => 'בקשות';

  @override
  String get tabActive => 'פעילות';

  @override
  String get heldByOther => 'משויכת כרגע לאחר';

  @override
  String get endAssignment => 'סיום שיוך';

  @override
  String get assignmentApproved => 'השיוך אושר';

  @override
  String get assignmentRejected => 'השיוך נדחה';

  @override
  String get residentLabel => 'תושב/ת';

  @override
  String get disputesTitle => 'מחלוקות';

  @override
  String get noDisputes => 'אין מחלוקות 🎉';

  @override
  String get resolve => 'סגירת מחלוקת';

  @override
  String get serviceDelivered => 'האם השירות ניתן?';

  @override
  String get resolutionNote => 'הערה (חובה)';

  @override
  String get resolvedChip => 'נסגרה';

  @override
  String get openChip => 'פתוחה';

  @override
  String get youArePartyNote => 'אתם צד במחלוקת הזו. הסגירה מסומנת ביומן.';

  @override
  String get statsTitle => 'סטטיסטיקה';

  @override
  String get statApartments => 'דירות';

  @override
  String get statResidents => 'תושבים מאושרים';

  @override
  String get statActiveWeek => 'פעילים השבוע';

  @override
  String get statListings => 'חניות שפורסמו';

  @override
  String get statReservations => 'הזמנות חניה';

  @override
  String get statRequests => 'בקשות איסוף';

  @override
  String get statDoneParking => 'עסקאות חניה שהושלמו';

  @override
  String get statDonePickup => 'איסופים שהושלמו';

  @override
  String get statCompletion => 'שיעור השלמה';

  @override
  String get statRating => 'דירוג ממוצע';

  @override
  String get activityTitle => 'פעילות בבניין';

  @override
  String get tabListings => 'חניות';

  @override
  String get tabPackages => 'חבילות';

  @override
  String get tabTransactions => 'עסקאות';

  @override
  String get joinCodeTitle => 'קוד הצטרפות';

  @override
  String get joinCodeHint =>
      'שתפו את הקוד עם השכנים. הקוד רק מזהה את הבניין — האישור שלכם הוא ההגנה.';

  @override
  String get rotateCode => 'החלפת קוד';

  @override
  String get posterTitle => 'כרזה להדפסה';

  @override
  String posterBody(String building) {
    return 'סרקו או הקלידו את הקוד כדי להצטרף ל$building';
  }

  @override
  String get selfReviewSwitch => 'אישור עצמי של המנהל';

  @override
  String get selfReviewHint =>
      'מאפשר לכם לאשר את הבקשות של עצמכם כל עוד אתם המנהל/ת היחיד/ה';

  @override
  String get buildingInfo => 'פרטי הבניין';

  @override
  String apartmentsCount(String n) {
    return '$n דירות';
  }

  @override
  String spacesCount(String n) {
    return '$n חניות';
  }

  @override
  String get platformTitle => 'ניהול פלטפורמה';

  @override
  String get buildingsTitle => 'בניינים';

  @override
  String get createBuilding => 'יצירת בניין';

  @override
  String get bDraft => 'טיוטה';

  @override
  String get bActive => 'פעיל';

  @override
  String get bSuspended => 'מושעה';

  @override
  String get stepDetails => 'פרטים';

  @override
  String get stepApartments => 'דירות';

  @override
  String get stepParking => 'חניות';

  @override
  String get stepReview => 'סיכום';

  @override
  String get buildingName => 'שם הבניין';

  @override
  String get buildingAddress => 'כתובת מלאה';

  @override
  String get cityLabel => 'עיר';

  @override
  String get apartmentCount => 'מספר דירות';

  @override
  String get parkingCount => 'מספר חניות';

  @override
  String get rangeGenerator => 'יצירה לפי טווח';

  @override
  String get rangeApartmentsHint => 'קומות 1–6, 4 דירות בקומה → 101…604';

  @override
  String get rangeParkingHint => 'P01–P24';

  @override
  String get pasteList => 'הדבקת רשימה';

  @override
  String get previewLabel => 'תצוגה מקדימה';

  @override
  String countMatch(String have, String want) {
    return '$have מתוך $want ✓';
  }

  @override
  String get checklistTitle => 'רשימת בדיקה להפעלה';

  @override
  String get chkApartments => 'רשימת דירות';

  @override
  String get chkSpaces => 'רשימת חניות';

  @override
  String get chkCounts => 'המספרים תואמים';

  @override
  String get chkAgreement => 'הסכם בניין (נוסח זמני)';

  @override
  String get acceptActivate => 'אישור ההסכם והפעלת הבניין';

  @override
  String get buildingActivated => 'הבניין הופעל';

  @override
  String get suspend => 'השעיה';

  @override
  String get reactivate => 'הפעלה מחדש';

  @override
  String get noAdminAppointNote =>
      'אתם מנהל/ת הבניין באופן אוטומטי. אין צורך למנות מנהלים.';

  @override
  String demoAcceptOffer(String name) {
    return 'הדגמה: $name מאשר/ת את ההצעה שלי';
  }

  @override
  String get demoEnterCode => 'הדגמה: השכן מזין את הקוד שלכם';

  @override
  String demoConfirmReceived(String name) {
    return 'הדגמה: $name מאשר/ת קבלה';
  }
}
