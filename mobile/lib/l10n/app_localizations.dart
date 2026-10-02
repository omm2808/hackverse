import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_or.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('or')
  ];

  /// Main application title
  ///
  /// In en, this message translates to:
  /// **'Fit Odyssey'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get navWorkout;

  /// No description provided for @navJourney.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get navJourney;

  /// No description provided for @navLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get navLeaderboard;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @exerciseSquat.
  ///
  /// In en, this message translates to:
  /// **'Squats'**
  String get exerciseSquat;

  /// No description provided for @exercisePushup.
  ///
  /// In en, this message translates to:
  /// **'Push-ups'**
  String get exercisePushup;

  /// No description provided for @exercisePlank.
  ///
  /// In en, this message translates to:
  /// **'Plank'**
  String get exercisePlank;

  /// No description provided for @calibrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Calibration'**
  String get calibrationTitle;

  /// No description provided for @calibrationStepBody.
  ///
  /// In en, this message translates to:
  /// **'Step back until your entire body is visible in the frame.'**
  String get calibrationStepBody;

  /// No description provided for @calibrationGood.
  ///
  /// In en, this message translates to:
  /// **'Position calibrated. Get ready!'**
  String get calibrationGood;

  /// No description provided for @calibrationLowConfidence.
  ///
  /// In en, this message translates to:
  /// **'Low confidence. Adjust lighting or camera angle.'**
  String get calibrationLowConfidence;

  /// No description provided for @cueGoodDepth.
  ///
  /// In en, this message translates to:
  /// **'Good depth!'**
  String get cueGoodDepth;

  /// No description provided for @cueGoLower.
  ///
  /// In en, this message translates to:
  /// **'Go slightly lower'**
  String get cueGoLower;

  /// No description provided for @cueChestUp.
  ///
  /// In en, this message translates to:
  /// **'Keep chest upright'**
  String get cueChestUp;

  /// No description provided for @cueKneesOut.
  ///
  /// In en, this message translates to:
  /// **'Push knees outward'**
  String get cueKneesOut;

  /// No description provided for @cueRaiseHips.
  ///
  /// In en, this message translates to:
  /// **'Raise your hips'**
  String get cueRaiseHips;

  /// No description provided for @cueLowerHips.
  ///
  /// In en, this message translates to:
  /// **'Lower your hips'**
  String get cueLowerHips;

  /// No description provided for @workoutComplete.
  ///
  /// In en, this message translates to:
  /// **'Workout Complete!'**
  String get workoutComplete;

  /// No description provided for @repsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Reps Completed'**
  String get repsCompleted;

  /// No description provided for @holdDuration.
  ///
  /// In en, this message translates to:
  /// **'Hold Duration'**
  String get holdDuration;

  /// No description provided for @formAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Form Accuracy'**
  String get formAccuracy;

  /// No description provided for @xpEarned.
  ///
  /// In en, this message translates to:
  /// **'XP Earned'**
  String get xpEarned;

  /// No description provided for @kmGained.
  ///
  /// In en, this message translates to:
  /// **'Heritage KM Gained'**
  String get kmGained;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'Saved offline, will sync when connected'**
  String get syncPending;

  /// No description provided for @syncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Synced with server'**
  String get syncSuccess;

  /// No description provided for @heritageTitle.
  ///
  /// In en, this message translates to:
  /// **'Odisha Golden Triangle Trek'**
  String get heritageTitle;

  /// No description provided for @heritageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lingaraj Temple to Konark Sun Temple (65 km)'**
  String get heritageSubtitle;

  /// No description provided for @checkpointUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Checkpoint Unlocked!'**
  String get checkpointUnlocked;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Campus Leaderboard'**
  String get leaderboardTitle;

  /// No description provided for @scopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get scopeGlobal;

  /// No description provided for @scopeCollege.
  ///
  /// In en, this message translates to:
  /// **'College'**
  String get scopeCollege;

  /// No description provided for @scopeHostel.
  ///
  /// In en, this message translates to:
  /// **'Hostel'**
  String get scopeHostel;

  /// No description provided for @periodWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get periodWeekly;

  /// No description provided for @periodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get periodMonthly;

  /// No description provided for @privacyConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy by Design'**
  String get privacyConsentTitle;

  /// No description provided for @privacyConsentBody.
  ///
  /// In en, this message translates to:
  /// **'Fit Odyssey processes your camera feed entirely on your phone. No videos, photos, or raw landmark coordinates are ever saved or uploaded to the cloud.'**
  String get privacyConsentBody;

  /// No description provided for @privacyAgree.
  ///
  /// In en, this message translates to:
  /// **'I Agree & Continue'**
  String get privacyAgree;

  /// No description provided for @under18Affirmation.
  ///
  /// In en, this message translates to:
  /// **'I affirm that I am 18 years of age or older.'**
  String get under18Affirmation;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'or'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'or':
      return AppLocalizationsOr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
