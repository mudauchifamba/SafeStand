# Suggested commit sequence

A clean, incremental git history is evidence to the judges that the team built
this over the challenge period. Make small, meaningful commits as real work
lands — don't squash everything into one "initial commit", and don't backdate.

This scaffold is a starting point. A natural sequence from here:

1. `chore: scaffold Flutter project + gitignore + README`
   (this commit — the skeleton, README, pubspec)

2. `data: add seed known-cases dataset and red-flag rules`
   (known_cases.json, red_flag_rules.json, specimen manifest)

3. `feat: add data models`
   (lib/models/models.dart)

4. `feat: implement rule-based risk scorer`
   (lib/services/risk_scorer.dart)

5. `test: add scorer unit tests (fraud/genuine/near-clean)`
   (test/risk_scorer_test.dart) — run `flutter test`, confirm green

6. `feat: load bundled dataset into scorer (repository)`
   (lib/services/case_repository.dart)

7. `feat: on-device OCR service via ML Kit`
   (lib/services/ocr_service.dart)

8. `feat: manual entry screen (stand number, area, seller)`

9. `feat: document scan screen + wire OCR to scorer`

10. `feat: verdict screen with Green/Amber/Red + reasons + next steps`

11. `feat: home screen tying the two input paths together`

12. `docs: add screenshots + demo notes to README`

## First-time setup

Because this scaffold was created before running `flutter create`, generate the
platform folders (android/, ios/) on top of it:

```bash
cd safestand
flutter create .          # fills in android/ios/etc without overwriting lib/
flutter pub get
flutter test              # scorer tests should pass
flutter run               # launch on an Android device/emulator
```

Then build the UI screens (steps 8-11). The scorer, data, OCR, and tests are
already done — the remaining work is Flutter UI wiring.

## Android permissions to add (android/app/src/main/AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

And in `android/app/build.gradle` ensure `minSdk` is at least 21 (ML Kit needs it).
