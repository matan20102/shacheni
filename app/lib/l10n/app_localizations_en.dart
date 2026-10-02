// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Shacheni';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get continueLabel => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get retry => 'Try again';

  @override
  String get seeAll => 'See all';

  @override
  String get send => 'Send';

  @override
  String get submit => 'Submit';

  @override
  String get edit => 'Edit';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get optional => 'optional';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get now => 'Now';

  @override
  String get free => 'Free';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get loadError => 'Couldn\'t load';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get call => 'Call';

  @override
  String get whatsapp => 'WhatsApp';

  @override
  String get youLabel => 'You';

  @override
  String verifiedResident(String building) {
    return 'Verified resident of $building';
  }

  @override
  String get newNeighbor => 'New neighbor';

  @override
  String completedCount(String n) {
    return '$n completed';
  }

  @override
  String memberSince(String year) {
    return 'Member since $year';
  }

  @override
  String inHM(String h, String m) {
    return 'in ${h}h ${m}m';
  }

  @override
  String inM(String m) {
    return 'in $m min';
  }

  @override
  String get overdue => 'Overdue';

  @override
  String untilTime(String time) {
    return 'By $time';
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
  String get navHome => 'Home';

  @override
  String get navParking => 'Parking';

  @override
  String get navPackages => 'Packages';

  @override
  String get navMe => 'Me';

  @override
  String get notificationsTooltip => 'Notifications';

  @override
  String get paymentNotice =>
      'Payment is arranged directly between neighbors (cash, Bit, PayBox…). The app doesn\'t process or hold money.';

  @override
  String get demoBadge => 'DEMO';

  @override
  String get demoNote =>
      'This is a prototype with sample data. Nothing is saved to a server.';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusDeclined => 'Declined';

  @override
  String get statusActive => 'Active';

  @override
  String get statusAvailable => 'Available';

  @override
  String get statusReserved => 'Reserved';

  @override
  String get welcomeTitle => 'Parking, mutual help — all inside your building';

  @override
  String get welcomeBullet1 => 'Share an idle parking space with neighbors';

  @override
  String get welcomeBullet2 => 'Ask for or offer a package pickup';

  @override
  String get welcomeBullet3 =>
      'Verified residents only. Your privacy comes first.';

  @override
  String get getStarted => 'Get started';

  @override
  String get skipToDemo => 'Skip to the demo';

  @override
  String get phoneTitle => 'What\'s your phone number?';

  @override
  String get phoneSubtitle => 'We\'ll text you a verification code';

  @override
  String get sendCode => 'Send code';

  @override
  String get phoneInvalid => 'Invalid phone number';

  @override
  String get otpTitle => 'Enter the code';

  @override
  String otpSubtitle(String phone) {
    return 'We sent a code to $phone';
  }

  @override
  String get otpChange => 'Change number';

  @override
  String get otpResend => 'Resend';

  @override
  String otpResendIn(String s) {
    return 'Resend in ${s}s';
  }

  @override
  String get verify => 'Verify';

  @override
  String get otpDemoHint => 'In the demo any code works (e.g. 123456)';

  @override
  String get legalTitle => 'Before you continue';

  @override
  String get legalSubtitle => 'Please read and accept these documents';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get communityRules => 'Community rules';

  @override
  String get residentDeclaration => 'Resident declaration';

  @override
  String get buildingAgreement => 'Building agreement';

  @override
  String legalVersion(String version) {
    return 'Version $version';
  }

  @override
  String get legalRead => 'Read';

  @override
  String get legalAccept => 'I have read and accept';

  @override
  String get legalPlaceholderNote =>
      'Placeholder document: the full legal text will be published by the app owner.';

  @override
  String get legalAcceptContinue => 'Accept and continue';

  @override
  String get joinTitle => 'Which building do you live in?';

  @override
  String get joinSubtitle => 'Enter the building code you got from the admin';

  @override
  String get joinCodeLabel => 'Building code';

  @override
  String get joinFind => 'Find building';

  @override
  String get joinFound => 'We found your building:';

  @override
  String get joinConfirm => 'Yes, this is my building';

  @override
  String get joinInvalid => 'That code isn\'t valid';

  @override
  String joinDemoHint(String code) {
    return 'Demo code: $code';
  }

  @override
  String get applyTitle => 'Request to join';

  @override
  String get applySubtitle =>
      'The building admin will verify that you live here';

  @override
  String get fullName => 'Full name';

  @override
  String get apartment => 'Apartment';

  @override
  String get apartmentPick => 'Choose apartment';

  @override
  String get parkingSpaces => 'Parking spaces';

  @override
  String get parkingOptionalHint =>
      'If you have a private space, pick it from the list';

  @override
  String get noParking => 'I have no private parking';

  @override
  String get declarationsTitle => 'Declarations';

  @override
  String get decl1 => 'The information I provided is accurate';

  @override
  String get decl2 => 'I am a resident of this building';

  @override
  String get decl3 => 'My apartment details are correct';

  @override
  String get decl4 => 'My parking details are correct';

  @override
  String get decl5 => 'I understand the community rules';

  @override
  String get submitRequest => 'Submit request';

  @override
  String get optionalPhoto => 'Profile photo (optional)';

  @override
  String get fieldRequired => 'Required field';

  @override
  String pendingTitle(String building) {
    return 'We\'re verifying that you live at $building';
  }

  @override
  String get pendingBody =>
      'Usually within a day. We\'ll notify you once you\'re approved.';

  @override
  String get pendingSummary => 'What you submitted';

  @override
  String get pendingDemoApprove => 'Demo: approve me as the admin';

  @override
  String get withdrawRequest => 'Withdraw request';

  @override
  String get logOut => 'Log out';

  @override
  String homeGreeting(String name) {
    return 'Hi $name 👋';
  }

  @override
  String get homeQuestion => 'What can you do in your building right now?';

  @override
  String get qaFindParking => 'Find parking';

  @override
  String get qaShareParking => 'Share my parking';

  @override
  String get qaRequestPickup => 'Request a pickup';

  @override
  String get qaHelp => 'Help a neighbor';

  @override
  String get needsAction => 'Needs your action';

  @override
  String get happeningSoon => 'Happening soon';

  @override
  String get parkingNow => 'Parking available';

  @override
  String get pickupNeighbors => 'Neighbors who need a pickup';

  @override
  String get nothingYet => 'Nothing happening yet';

  @override
  String get beFirst => 'Be the first to share parking or ask for help';

  @override
  String actRespondRequest(String name, String space) {
    return '$name requested parking $space';
  }

  @override
  String actConfirmReservation(String space) {
    return 'Confirm your booking of $space';
  }

  @override
  String get actShowCode => 'Show your handoff code';

  @override
  String actHelperArrived(String name) {
    return '$name arrived with your package';
  }

  @override
  String get actViewPhoto => 'Package left by your door — view the photo';

  @override
  String actPayPay(String amount, String name) {
    return 'Mark that you paid ₪$amount to $name';
  }

  @override
  String actPayReceived(String amount, String name) {
    return '$name says they paid ₪$amount';
  }

  @override
  String actRate(String name) {
    return 'Rate $name';
  }

  @override
  String actOfferReceived(String name) {
    return '$name offered to pick up your package';
  }

  @override
  String actHelperJob(String name) {
    return 'Pickup for $name';
  }

  @override
  String soonReservation(String space, String window) {
    return 'Parking $space · $window';
  }

  @override
  String soonJob(String place) {
    return 'Pickup: $place';
  }

  @override
  String get parkingTitle => 'Parking';

  @override
  String get segFind => 'Find';

  @override
  String get segMine => 'Mine';

  @override
  String get segSharing => 'Sharing';

  @override
  String get segRenting => 'Renting';

  @override
  String get whenNeedParking => 'When do you need parking?';

  @override
  String get presetTonight => 'Tonight';

  @override
  String get presetTomorrow => 'Tomorrow';

  @override
  String get presetWeek => 'This week';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get showAllUpcoming => 'Show all upcoming';

  @override
  String get coversYourTime => 'Covers your time';

  @override
  String get instantBadge => 'Instant';

  @override
  String get approvalBadge => 'Owner approves';

  @override
  String get noSpacesTitle => 'No spaces for these times';

  @override
  String get noSpacesMsg => 'Try a wider range or show all upcoming';

  @override
  String parkingLabel(String space) {
    return 'Parking $space';
  }

  @override
  String get listingDetailTitle => 'Parking details';

  @override
  String get requestAction => 'Request';

  @override
  String get reserveNow => 'Reserve now';

  @override
  String get ownListing => 'This is your space';

  @override
  String get offeredBy => 'Offered by';

  @override
  String get whenLabel => 'When';

  @override
  String get priceLabel => 'Price';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get reviewTitle => 'Review & send';

  @override
  String get vehiclePlate => 'Vehicle plate (optional)';

  @override
  String get noteToOwner => 'Note to the owner';

  @override
  String get sendRequest => 'Send request';

  @override
  String get requestSentSnack => 'Request sent to the owner';

  @override
  String get reservedSnack => 'Parking reserved';

  @override
  String get slotTaken => 'Someone just booked this space';

  @override
  String get publishTitle => 'Share parking';

  @override
  String get chooseSpace => 'Choose a space';

  @override
  String get startsLabel => 'Starts';

  @override
  String get endsLabel => 'Ends';

  @override
  String get priceInput => 'Price (₪)';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get approveEach => 'I approve each request';

  @override
  String get approveEachHint => 'When off, bookings are instant';

  @override
  String get publish => 'Publish';

  @override
  String get publishedSnack => 'Space published';

  @override
  String get noAssignmentTitle => 'No parking space is linked to you';

  @override
  String get noAssignmentMsg =>
      'To share parking, request an assignment and the admin will verify it';

  @override
  String get requestAssignmentBtn => 'Request a parking assignment';

  @override
  String get overlapError => 'You already offered this space during this time';

  @override
  String get invalidWindow => 'End must be after start';

  @override
  String get needsResponse => 'Needs response';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get past => 'Past';

  @override
  String get emptySharing => 'You haven\'t shared a space yet';

  @override
  String get emptyRenting => 'You have no parking bookings';

  @override
  String get requestsTitle => 'Requests';

  @override
  String get noRequestsYet =>
      'No requests yet. Your space is visible to neighbors.';

  @override
  String get cancelAvailability => 'Cancel availability';

  @override
  String get cancelAvailabilityBody =>
      'Pending requests will be declined and the neighbors notified.';

  @override
  String get acceptWarn =>
      'Accepting will decline the other requests for the same time.';

  @override
  String get resRequested => 'Waiting for approval';

  @override
  String get resAccepted => 'Accepted — please confirm';

  @override
  String get resConfirmed => 'Booked';

  @override
  String get resActive => 'In use';

  @override
  String get resCompleted => 'Ended';

  @override
  String get stepRequested => 'Request';

  @override
  String get stepAccepted => 'Accepted';

  @override
  String get stepConfirmed => 'Booked';

  @override
  String get stepActive => 'In use';

  @override
  String get stepEnded => 'Ended';

  @override
  String get reservationTitle => 'Booking details';

  @override
  String get confirmReservation => 'Confirm booking';

  @override
  String confirmBy(String time) {
    return 'Confirm by $time';
  }

  @override
  String confirmSheetBody(String name) {
    return 'You\'ll arrange payment directly with $name. The app doesn\'t process or hold money.';
  }

  @override
  String get contactAfter => 'Contact details appear after final confirmation';

  @override
  String get vehicleLabel => 'Vehicle';

  @override
  String get noteLabel => 'Note';

  @override
  String demoAcceptReq(String name) {
    return 'Demo: $name accepts the request';
  }

  @override
  String get demoEndBooking => 'Demo: the booking window ends';

  @override
  String get mySpacesTitle => 'My parking spaces';

  @override
  String get assignActive => 'Verified';

  @override
  String get assignRequested => 'Awaiting verification';

  @override
  String get assignRejected => 'Rejected';

  @override
  String get assignEnded => 'Ended';

  @override
  String get withdrawRequestShort => 'Withdraw';

  @override
  String get noSpacesLinked => 'No parking spaces linked to you';

  @override
  String get requestAssignTitle => 'Request a parking assignment';

  @override
  String get assignHint =>
      'The admin will verify the space is yours before linking it.';

  @override
  String get pickSpace => 'Pick a space from the list';

  @override
  String get sendAssignRequest => 'Send request to the admin';

  @override
  String get assignSentSnack => 'Request sent to the admin';

  @override
  String get cancelBookingTitle => 'Cancel booking';

  @override
  String get pkgTitle => 'Packages';

  @override
  String get segHelp => 'Help';

  @override
  String get segMyRequests => 'My requests';

  @override
  String get segMyOffers => 'My offers';

  @override
  String get filterToday => 'Today';

  @override
  String get filterReward => 'Highest reward';

  @override
  String get rewardLabel => 'Reward';

  @override
  String get doorOkBadge => 'Door delivery OK';

  @override
  String get noRequestsTitle => 'No one needs a pickup right now 🎉';

  @override
  String get noRequestsMsg => 'Need something picked up? Ask a neighbor.';

  @override
  String get newPickupTitle => 'Request a pickup';

  @override
  String get pickupLocation => 'Pickup location';

  @override
  String get pickupLocationHint => 'e.g. Azrieli Mall';

  @override
  String get pkgDescription => 'Package description';

  @override
  String get pkgDescriptionHint => 'Small box, about 1 kg';

  @override
  String get deadlineLabel => 'Deadline';

  @override
  String get rewardChoose => 'Reward';

  @override
  String get notesLabel => 'Notes';

  @override
  String get pickupRef => 'Order number / pickup code';

  @override
  String get pickupRefHint =>
      'Private — shared only with the neighbor you choose';

  @override
  String get handoffPlace => 'Handoff place';

  @override
  String get defaultLobby => 'Building lobby';

  @override
  String get doorToggle => 'Allow leaving the package near my apartment door';

  @override
  String get doorToggleHint => 'The helper must send you a photo as proof';

  @override
  String get ackProhibited => 'No prohibited items (cash, IDs, medication…)';

  @override
  String get ackThirdParty => 'The pickup point lets someone collect for me';

  @override
  String get postRequest => 'Post request';

  @override
  String get postedSnack => 'Request posted';

  @override
  String get deadlineTooSoon => 'Deadline must be at least 30 minutes ahead';

  @override
  String get offerToPickup => 'Offer to pick up';

  @override
  String get withdrawOffer => 'Withdraw offer';

  @override
  String get offerSheetTitle => 'Offer to pick up';

  @override
  String get plannedTime => 'When will you go? (optional)';

  @override
  String get messageOptional => 'Message (optional)';

  @override
  String get sendOffer => 'Send offer';

  @override
  String get offerSentSnack => 'Offer sent';

  @override
  String get offerPending => 'Your offer was sent and is waiting';

  @override
  String get hiddenDetails =>
      'The apartment and pickup details appear once your offer is accepted.';

  @override
  String get reqOpen => 'Open';

  @override
  String get reqOffers => 'Offers received';

  @override
  String get reqAccepted => 'Offer accepted';

  @override
  String get reqCollected => 'Collected';

  @override
  String get reqDelivered => 'Delivered';

  @override
  String get reqCompleted => 'Completed';

  @override
  String get reqCancelled => 'Cancelled';

  @override
  String get reqExpired => 'Expired';

  @override
  String get reqDisputed => 'Under review';

  @override
  String get stOpen => 'Open';

  @override
  String get stOffers => 'Offers';

  @override
  String get stAccepted => 'Accepted';

  @override
  String get stCollected => 'Collected';

  @override
  String get stDelivered => 'Delivered';

  @override
  String get stCompleted => 'Done';

  @override
  String get offersTitle => 'Offers';

  @override
  String get noOffersYet =>
      'Neighbors were notified. We\'ll tell you when someone offers.';

  @override
  String offerAt(String time) {
    return 'Going around $time';
  }

  @override
  String get yourHelper => 'Your helper';

  @override
  String get codePanelTitle => 'Your handoff code';

  @override
  String get codeHint => 'Say the code only when you have the package';

  @override
  String get regenerateCode => 'Generate a new code';

  @override
  String regenLeft(String n) {
    return '$n left';
  }

  @override
  String get allowDoor => 'Allow leaving it by my door';

  @override
  String get doorAllowedNote =>
      'Allowed — your neighbor will attach a photo as proof';

  @override
  String arrivalBanner(String name) {
    return '$name arrived with your package';
  }

  @override
  String get deliveryPhoto => 'Delivery photo';

  @override
  String photoTakenAt(String name, String time) {
    return 'Taken $time by $name';
  }

  @override
  String get confirmReceived => 'Confirm received';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String autoConfirmNote(String time) {
    return 'No response — auto-confirmed in $time';
  }

  @override
  String get cancelRequestBtn => 'Cancel request';

  @override
  String get jobTitle => 'Pickup job';

  @override
  String get pickupBlock => 'Pick up';

  @override
  String get deliverTo => 'Deliver to';

  @override
  String apartmentLabel(String apt) {
    return 'Apt $apt';
  }

  @override
  String get pickupRefLabel => 'Pickup reference';

  @override
  String get iPickedUp => 'I picked up the package';

  @override
  String get imHere => 'I\'ve arrived';

  @override
  String arrivalSent(String name) {
    return 'We told $name you\'ve arrived';
  }

  @override
  String get enterCode => 'Enter handoff code';

  @override
  String get cantHandOver => 'Can\'t hand over in person?';

  @override
  String get withdrawJob => 'Withdraw from the job';

  @override
  String get codeEntryTitle => 'Handoff code';

  @override
  String codeEntryHint(String name) {
    return 'Ask $name for the 4-digit code';
  }

  @override
  String get confirmDelivery => 'Confirm delivery';

  @override
  String wrongCode(String n) {
    return 'That code doesn\'t match. $n attempts left.';
  }

  @override
  String lockedCode(String time) {
    return 'Too many attempts. Try again in $time.';
  }

  @override
  String get deliveredTitle => 'Delivered! 🎉';

  @override
  String get deliveredBody =>
      'Delivery confirmed. Now just settle the payment.';

  @override
  String get methodsTitle => 'How to hand over?';

  @override
  String get methodPhone => 'Get the code by phone';

  @override
  String get methodPhoneHint =>
      'The requester can read you the code even if they\'re not home';

  @override
  String get methodDoor => 'Leave it near the apartment door';

  @override
  String get methodDoorHint =>
      'Needs the requester\'s permission and a proof photo';

  @override
  String askAllow(String name) {
    return 'Ask $name to allow it';
  }

  @override
  String allowAsked(String name) {
    return 'We asked $name to allow door delivery';
  }

  @override
  String get methodUnreachable => 'I can\'t reach them';

  @override
  String get methodUnreachableHint =>
      'You keep the package and the case goes to review';

  @override
  String get allowSheetTitle => 'Your neighbor is here with your package';

  @override
  String get allowSheetBody =>
      'You can come down, read out the code, or allow leaving it by your door. You\'ll get a photo as proof.';

  @override
  String get showMyCode => 'Show my code';

  @override
  String get allowLeaving => 'Allow leaving it by my door';

  @override
  String get illComeDown => 'I\'ll come down';

  @override
  String get doorPhotoTitle => 'Door delivery';

  @override
  String get doorPhotoGuide =>
      'Photograph the package near the door. Avoid people and other residents\' doors.';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get retake => 'Retake';

  @override
  String get submitDelivery => 'Submit delivery';

  @override
  String get doorPhotoSuccess => 'Delivered — the requester was notified';

  @override
  String get cameraDemoHint =>
      'The demo shows a sample picture instead of the camera';

  @override
  String get photoViewerTitle => 'Delivery photo';

  @override
  String get photoSample => 'Sample photo';

  @override
  String photoMeta(String name, String time) {
    return 'Taken $time · uploaded by $name';
  }

  @override
  String photoNote(String note) {
    return 'Courier note: $note';
  }

  @override
  String get photoRetention => 'The photo is kept for 30 days';

  @override
  String get demoOffer => 'Demo: a neighbor offers to pick up';

  @override
  String get demoCollected => 'Demo: the helper collected the package';

  @override
  String get demoArrival => 'Demo: the helper arrives';

  @override
  String get demoDoorDelivery =>
      'Demo: the helper leaves it by the door with a photo';

  @override
  String get payTitle => 'Payment';

  @override
  String get iPaid => 'I paid';

  @override
  String waitingConfirm(String name) {
    return 'Waiting for $name to confirm';
  }

  @override
  String waitingPay(String name) {
    return 'Waiting for $name to pay';
  }

  @override
  String saidPaid(String amount, String name) {
    return '$name says they paid ₪$amount';
  }

  @override
  String get paymentReceived => 'Payment received';

  @override
  String get notReceived => 'Not received';

  @override
  String get noPaymentNeeded => 'No payment needed';

  @override
  String get settledLabel => 'Payment settled';

  @override
  String get paymentCancelled => 'Payment cancelled';

  @override
  String youPayTo(String amount, String name) {
    return 'You pay ₪$amount to $name';
  }

  @override
  String youReceiveFrom(String amount, String name) {
    return 'You receive ₪$amount from $name';
  }

  @override
  String get payPending => 'Awaiting payment';

  @override
  String get payConfirmed => 'Marked as paid';

  @override
  String get paySettled => 'Paid';

  @override
  String get payCancelled => 'Cancelled';

  @override
  String demoPayerPaid(String name) {
    return 'Demo: $name marks it as paid';
  }

  @override
  String demoPayeeConfirm(String name) {
    return 'Demo: $name confirms payment';
  }

  @override
  String get txDetailTitle => 'Transaction details';

  @override
  String get txInProgress => 'In progress';

  @override
  String get txAwaiting => 'Awaiting payment';

  @override
  String get txCompleted => 'Completed';

  @override
  String get txCancelled => 'Cancelled';

  @override
  String get txDisputed => 'Under review';

  @override
  String get youPaid => 'You paid';

  @override
  String get youReceived => 'You received';

  @override
  String get refundRecord => 'A separate refund record was created';

  @override
  String get paymentTimeline => 'Payment timeline';

  @override
  String get counterparty => 'Other party';

  @override
  String get txTypeParking => 'Parking';

  @override
  String get txTypePickup => 'Package pickup';

  @override
  String get historyTitle => 'History';

  @override
  String get filterAll => 'All';

  @override
  String get filterParking => 'Parking';

  @override
  String get filterPickups => 'Pickups';

  @override
  String get filterPaid => 'I paid';

  @override
  String get filterReceived => 'I received';

  @override
  String get historyEmpty => 'Your activity will appear here';

  @override
  String historyTotals(String earned, String paid) {
    return 'You paid ₪$paid · received ₪$earned';
  }

  @override
  String rateTitle(String name) {
    return 'Rate $name';
  }

  @override
  String get rateComment => 'Add a comment (optional)';

  @override
  String get notNow => 'Not now';

  @override
  String get rateThanks => 'Thanks for rating';

  @override
  String get rateHidden =>
      'Ratings appear once both have rated, or after 14 days';

  @override
  String get rateButton => 'Rate';

  @override
  String get alreadyRated => 'You already rated';

  @override
  String get cancelTitle => 'Cancel';

  @override
  String get consequences => 'What happens:';

  @override
  String get consOther => 'The other party is notified';

  @override
  String get consRefund =>
      'If it was already paid, a separate refund record is created';

  @override
  String get consCounter => 'The cancellation counts in your reliability';

  @override
  String get confirmCancel => 'Confirm cancellation';

  @override
  String get keepIt => 'Keep it';

  @override
  String get cancelledSnack => 'Cancelled';

  @override
  String get reportTitle => 'Report a problem';

  @override
  String get reportReason => 'Reason';

  @override
  String get rSpaceOccupied => 'The space was occupied';

  @override
  String get rNotDelivered => 'The package wasn\'t delivered';

  @override
  String get rPaymentNotReceived => 'Payment wasn\'t received';

  @override
  String get rUnreachable => 'The requester is unreachable';

  @override
  String get rOther => 'Other';

  @override
  String get reportDesc => 'What happened?';

  @override
  String get reportNote =>
      'A building admin will review within 48 hours; automatic actions are paused.';

  @override
  String get submitReport => 'Submit report';

  @override
  String get reportSent => 'Report sent';

  @override
  String get profileTitle => 'Neighbor profile';

  @override
  String get reviewsTitle => 'Reviews';

  @override
  String get noReviews => 'No reviews yet';

  @override
  String get privateInfoNote =>
      'Apartment and phone aren\'t shown to neighbors';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get allCaughtUp => 'You\'re all caught up 🎉';

  @override
  String nParkingRequest(String name, String space) {
    return '$name requested parking $space';
  }

  @override
  String nParkingAccepted(String name) {
    return '$name accepted — confirm to book';
  }

  @override
  String nOfferReceived(String name) {
    return '$name offered to pick up your package';
  }

  @override
  String nCollected(String name) {
    return '$name collected your package';
  }

  @override
  String nArrived(String name) {
    return '$name arrived with your package';
  }

  @override
  String get nDoorDelivered =>
      'Your package was left by the door — photo attached';

  @override
  String nMarkedPaid(String name) {
    return '$name marked the payment as paid';
  }

  @override
  String nRatingRequested(String name) {
    return 'Rate $name';
  }

  @override
  String get nApproved => 'You were approved as a resident!';

  @override
  String agoMinutes(String m) {
    return '$m min ago';
  }

  @override
  String agoHours(String h) {
    return '$h h ago';
  }

  @override
  String agoDays(String d) {
    return '$d d ago';
  }

  @override
  String get meTitle => 'Me';

  @override
  String apartmentIn(String apt, String building) {
    return 'Apt $apt · $building';
  }

  @override
  String get editProfile => 'Edit profile';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get helpLabel => 'Help & contact';

  @override
  String get adminArea => 'Building admin';

  @override
  String get platformArea => 'Platform admin';

  @override
  String get languageLabel => 'Language';

  @override
  String get hebrew => 'עברית';

  @override
  String get english => 'English';

  @override
  String get notifSettings => 'Notifications';

  @override
  String get notifNewPickup => 'New pickup requests';

  @override
  String get notifNewParking => 'New parking spaces';

  @override
  String get alwaysOn => 'Transaction notifications are always on';

  @override
  String get legalDocs => 'Legal documents';

  @override
  String get appVersion => 'App version';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteBlocked =>
      'You can\'t delete your account while transactions are active';

  @override
  String get showDemoTools => 'Show demo buttons';

  @override
  String get demoSection => 'Demo';

  @override
  String get resetDemo => 'Reset demo data';

  @override
  String get profileEditNote =>
      'Changing your apartment submits a new request for admin approval.';

  @override
  String get adminTitle => 'Building admin';

  @override
  String get adminHello => 'Hello, building admin';

  @override
  String get adminPendingApps => 'Join requests';

  @override
  String get adminParkingRequests => 'Parking assignment requests';

  @override
  String get adminDisputes => 'Disputes';

  @override
  String get adminActivity => 'Building activity';

  @override
  String get adminStats => 'Statistics';

  @override
  String get adminSettings => 'Building settings';

  @override
  String get adminResidents => 'Residents';

  @override
  String get adminApartments => 'Apartments';

  @override
  String get adminSpaces => 'Parking spaces';

  @override
  String get selfReviewBanner =>
      'As the only admin you may approve yourself. The action is flagged in the audit log.';

  @override
  String get applicationsTitle => 'Join requests';

  @override
  String get tabPending => 'Pending';

  @override
  String get tabDecided => 'Decided';

  @override
  String get noPending => 'No one is waiting 🎉';

  @override
  String get reviewTitle2 => 'Review request';

  @override
  String get nameLabel => 'Name';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get requestedParking => 'Requested parking';

  @override
  String get flagSecondResident => 'Another resident in this apartment';

  @override
  String get flagHeldByOther =>
      'This space is currently assigned to someone else';

  @override
  String get flagOwn => 'This is your own request';

  @override
  String get approveApplication => 'Approve';

  @override
  String get rejectApplication => 'Reject';

  @override
  String get requestInfo => 'Request more info';

  @override
  String alsoApproveParking(String space) {
    return 'Also approve parking $space';
  }

  @override
  String get applicationApproved => 'Request approved';

  @override
  String get applicationRejected => 'Request rejected';

  @override
  String get infoRequested => 'Asked for more information';

  @override
  String submittedAgo(String when) {
    return 'Submitted $when';
  }

  @override
  String get assignmentsTitle => 'Parking assignments';

  @override
  String get tabRequests => 'Requests';

  @override
  String get tabActive => 'Active';

  @override
  String get heldByOther => 'Currently held by someone else';

  @override
  String get endAssignment => 'End assignment';

  @override
  String get assignmentApproved => 'Assignment approved';

  @override
  String get assignmentRejected => 'Assignment rejected';

  @override
  String get residentLabel => 'Resident';

  @override
  String get disputesTitle => 'Disputes';

  @override
  String get noDisputes => 'No disputes 🎉';

  @override
  String get resolve => 'Resolve';

  @override
  String get serviceDelivered => 'Was the service delivered?';

  @override
  String get resolutionNote => 'Note (required)';

  @override
  String get resolvedChip => 'Resolved';

  @override
  String get openChip => 'Open';

  @override
  String get youArePartyNote =>
      'You are a party to this dispute. Resolving is flagged in the audit log.';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statApartments => 'Apartments';

  @override
  String get statResidents => 'Approved residents';

  @override
  String get statActiveWeek => 'Active this week';

  @override
  String get statListings => 'Parking listings';

  @override
  String get statReservations => 'Reservations';

  @override
  String get statRequests => 'Pickup requests';

  @override
  String get statDoneParking => 'Completed parking';

  @override
  String get statDonePickup => 'Completed pickups';

  @override
  String get statCompletion => 'Completion rate';

  @override
  String get statRating => 'Average rating';

  @override
  String get activityTitle => 'Building activity';

  @override
  String get tabListings => 'Listings';

  @override
  String get tabPackages => 'Packages';

  @override
  String get tabTransactions => 'Transactions';

  @override
  String get joinCodeTitle => 'Join code';

  @override
  String get joinCodeHint =>
      'Share the code with neighbors. The code only identifies the building — your approval is the protection.';

  @override
  String get rotateCode => 'Rotate code';

  @override
  String get posterTitle => 'Printable poster';

  @override
  String posterBody(String building) {
    return 'Enter this code to join $building';
  }

  @override
  String get selfReviewSwitch => 'Admin self-review';

  @override
  String get selfReviewHint =>
      'Lets you approve your own requests while you\'re the only admin';

  @override
  String get buildingInfo => 'Building info';

  @override
  String apartmentsCount(String n) {
    return '$n apartments';
  }

  @override
  String spacesCount(String n) {
    return '$n parking spaces';
  }

  @override
  String get platformTitle => 'Platform admin';

  @override
  String get buildingsTitle => 'Buildings';

  @override
  String get createBuilding => 'Create building';

  @override
  String get bDraft => 'Draft';

  @override
  String get bActive => 'Active';

  @override
  String get bSuspended => 'Suspended';

  @override
  String get stepDetails => 'Details';

  @override
  String get stepApartments => 'Apartments';

  @override
  String get stepParking => 'Parking';

  @override
  String get stepReview => 'Review';

  @override
  String get buildingName => 'Building name';

  @override
  String get buildingAddress => 'Full address';

  @override
  String get cityLabel => 'City';

  @override
  String get apartmentCount => 'Number of apartments';

  @override
  String get parkingCount => 'Number of parking spaces';

  @override
  String get rangeGenerator => 'Generate from a range';

  @override
  String get rangeApartmentsHint => 'Floors 1–6, 4 per floor → 101…604';

  @override
  String get rangeParkingHint => 'P01–P24';

  @override
  String get pasteList => 'Paste a list';

  @override
  String get previewLabel => 'Preview';

  @override
  String countMatch(String have, String want) {
    return '$have of $want ✓';
  }

  @override
  String get checklistTitle => 'Activation checklist';

  @override
  String get chkApartments => 'Apartment list';

  @override
  String get chkSpaces => 'Parking space list';

  @override
  String get chkCounts => 'Counts match';

  @override
  String get chkAgreement => 'Building agreement (placeholder text)';

  @override
  String get acceptActivate => 'Accept agreement & activate';

  @override
  String get buildingActivated => 'Building activated';

  @override
  String get suspend => 'Suspend';

  @override
  String get reactivate => 'Reactivate';

  @override
  String get noAdminAppointNote =>
      'You become the building admin automatically. No admin appointment is needed.';

  @override
  String demoAcceptOffer(String name) {
    return 'Demo: $name accepts my offer';
  }

  @override
  String get demoEnterCode => 'Demo: the helper enters your code';

  @override
  String demoConfirmReceived(String name) {
    return 'Demo: $name confirms receipt';
  }
}
