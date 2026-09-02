# External TestFlight — copy/paste materials

Everything App Store Connect asks for when you turn on **external** testing,
written out so you paste rather than compose. Internal testing needs none of
this; external triggers **Beta App Review**, where a human at Apple reads these
fields and opens the app.

Fill order in App Store Connect: **TestFlight → Test Information** (the shared
fields), then **TestFlight → External Group → add build → Submit for Review**.

---

## 0. Status check before you start

The Family Controls **distribution** entitlement is already granted. This was
stale in every doc in the repo, which said "awaiting Apple approval". It is not
awaiting anything. Verified 2026-09-02 by archiving and exporting an App Store
IPA: Xcode issued `iOS Team Store Provisioning Profile: com.lemmego.app`
carrying `com.apple.developer.family-controls` and `beta-reports-active`, signed
by `Apple Distribution: Justin Tormey (5Y8S56DTEH)`.

Translation: the build uploads today. Nothing is blocked on Apple.

Privacy policy URL is live too, so nothing is outstanding on the submission side.
See section 6.

---

## 1. Beta App Description
*(TestFlight → Test Information → Beta App Description. Testers see this.)*

```
LemmeGo turns an NFC tag into a physical commitment device for your phone.

Stick a tag on your desk, inside a drawer, or on the fridge. Tap it and LemmeGo
starts a focus session: the apps you picked get blocked by iOS Screen Time until
the timer runs out or you tap the same tag again.

The point is friction, not willpower. Anyone can swipe away a focus app. Far
fewer people will get up and walk to the other room, which is the whole reason
the tag lives somewhere slightly inconvenient.

What you get:
- Timed sessions up to 23h 59m, or an unlimited session with no automatic end
- Lock Now starts a session without a tap, but you still need the tag to get out
- You pick exactly which apps and categories get blocked
- Five emergency unlocks a week, reset every Monday, so you are never truly stuck

Everything stays on the phone. No account, no sign-in, no network calls, no
analytics, no third-party SDKs. LemmeGo has no server to talk to.

You will need an NFC tag. Blank NTAG215 stickers cost a few dollars for a pack.
Most contactless cards with a fixed ID also work, including hotel key cards,
transit cards and building access badges.
```

## 2. What to Test
*(Per-build field. Rewrite it every build. This is version 1.2.0, build 1.)*

```
Build 1 (1.2.0) — first TestFlight build.

Two fixes here came out of a QA pass and have never run on a real device, so they
are the most valuable things you can confirm:

1. Screen Time on iOS 26.4 and later. Grant LemmeGo Screen Time access, then start
   a lock. A new iOS authorization state used to be read as "denied", so the app
   refused to lock at all for people who had granted permission. If you see
   "Screen Time permission is required" after you have already granted it, that bug
   is back and we want to hear immediately.

2. The emergency unlock counter on a Sunday. It should read the same on Sunday as
   it did on Saturday. It used to reset a day early and quietly hand you a second
   batch of five.

Then, in rough priority order:

3. Register a tag. Anything with a stable NFC ID works. Tell us what you used, and
   especially if a tag registered fine but then would not scan again.

4. Run a real session. Use a short duration first, one or two minutes. Confirm the
   apps you blocked are actually blocked, and that they work again when it ends.

5. Force-quit the app mid-session, then reopen it. You should land back on the lock
   screen with the right time left and your apps still blocked.

6. Let a session run past its end while LemmeGo is in the background, then open the
   app. See the note below about this one; we know it is not instant.

7. Tap the wrong tag while locked. It should refuse and say so.

8. Emergency unlock. Use one, confirm the count drops and your apps come back.

9. Try to start a lock with no apps selected, and with the duration set to
   0h 0m 0s. Both should now be refused with a message explaining why, rather than
   locking you into a session that enforces nothing.

Known and expected in this build:
- NFC does not work in the Simulator. This is device only.
- Portrait only, iPhone only, iOS 16 and up.
- When a timed session ends while LemmeGo is in the background, your apps stay
  blocked until you open LemmeGo. The notification tells you to. This is a real
  limitation we are fixing properly later; it is not you doing something wrong.
- Unlimited sessions never end on their own. The only ways out are a registered
  tag, an emergency unlock, or deleting the app. Do not start one unless a tag is
  in your hand.
- "Lock Now" can be released by any tag you have registered, since no particular
  tag started it. A session you started by scanning still needs that same tag.
- Changing your device clock will end a timed session early and can refill the
  emergency-unlock budget. Known, and not worth reporting.
```

## 3. Feedback email

```
jt@justintormey.com
```

## 4. Reviewer notes (App Review Information → Notes)

The one that matters. LemmeGo is unusable without an NFC tag, and an App Review
tester almost certainly does not have one on the desk. If you say nothing, the
reviewer opens the app, hits a setup screen demanding a tag they do not have,
and rejects with "we were unable to review your app". Answer it before it is
asked.

```
LemmeGo is a self-directed focus tool. The user taps their own NFC tag to block
their own apps for a set time. There is no parental control, no second user, no
remote party, no account and no server.

HOW TO TEST WITHOUT BUYING AN NFC TAG
This is the important part. LemmeGo needs a tag registered before it does
anything, and you do not need to buy one. It reads the plain hardware ID of any
ISO14443 or ISO15693 contactless tag, so all of the following work:
  - a hotel room key card
  - a transit card
  - an office or building access badge
  - most contactless credit or debit cards
LemmeGo reads only the tag's UID. It does not read, store, or transmit payment
data, and it has no ability to do so. It never writes to the tag.
Note: a small number of newer payment cards randomise their UID on every tap. If
a card registers but then will not unlock, it is one of those. Use a hotel key
card or transit card instead.

SUGGESTED REVIEW PATH
1. Launch. Tap "Register Your First Tag" and hold the card to the top of the
   phone. Give it any name.
2. Grant Screen Time access when asked. The app cannot block anything without it.
3. Settings, then choose a few apps to block. This is REQUIRED: LemmeGo refuses to
   start a session with an empty selection, rather than locking you into a session
   that blocks nothing.
4. Set the duration to 1 minute. Leave "Unlimited Duration" off.
5. Tap "Lock Now". Confirm the blocked apps are shielded.
6. Tap the same card to unlock, or wait a minute for it to expire on its own.

PLEASE DO NOT USE "UNLIMITED DURATION" while reviewing unless you still have the
card you registered. An unlimited session has no automatic end.

THE USER IS NEVER TRAPPED
Three independent ways out of any session, by design:
1. Tap the tag that started the session.
2. Emergency unlock, five per week, resetting Monday. It is one button on the
   lock screen and needs no tag.
3. Delete the app. LemmeGo's shields live in its own named ManagedSettingsStore,
   so removing the app removes every restriction it applied.
LemmeGo only ever shields the specific application, category and web-domain
tokens the user picked in Apple's own FamilyActivityPicker. It never applies a
blanket restriction: there is no call to ShieldSettings .all() anywhere in the
codebase, and if the user's selection is empty the app applies no shields at all
and says so on screen. It sets no other ManagedSettings properties, so it cannot
restrict installation, deletion, accounts, passcode changes, or Siri.

FAMILY CONTROLS USAGE
The Family Controls entitlement is used only for individual authorization
(AuthorizationCenter.requestAuthorization(for: .individual)) so the person
holding the phone can restrict their own apps. The app does not enrol children,
does not use DeviceActivity monitoring, does not report usage, and never reads
which apps the user actually opens. FamilyActivitySelection tokens are opaque to
us and are stored only on the device.

PRIVACY
No account, no sign-in, no data collection, no analytics, no third-party SDKs,
and no networking code of any kind. The app contains no URLSession usage and
makes no outbound connections. Everything it stores, including registered tag
IDs and emergency-unlock records, lives in the app's own UserDefaults on the
device. The privacy manifest declares zero collected data types and one
required-reason API (UserDefaults, CA92.1).

DEVICE
iPhone with NFC, iOS 16 or later. Portrait only. NFC hardware is not present in
the Simulator, so this must be reviewed on a physical iPhone.
```

## 5. Export compliance

Answered in the build. `ITSAppUsesNonExemptEncryption` is set to `false` in
`Info.plist`, so uploads no longer stop to ask. Accurate: LemmeGo performs no
cryptography at all. It has no networking, no TLS, no signing, no hashing of
user data. It is the rare app where "false" is literally true rather than an
exemption argument.

## 6. Privacy policy URL

**Live.** Paste this into App Store Connect (App Information → Privacy Policy URL, and
the TestFlight Test Information privacy policy field):

```
https://demo.justintormey.com/lemmego/privacy/
```

Published 2026-09-02 to the `lemmego/` prefix of the `justintormey.com` S3 bucket behind
CloudFront `E1R27W2LA6BBEH`, the same distribution serving `demo.justintormey.com/qr/`.
Source is `web/privacy/index.html`; redeploy with `./scripts/deploy` (`--dry-run` first).

Verified live: HTTP 200, `content-type: text/html`, and all three of `/lemmego/privacy/`,
`/lemmego/privacy`, and `/lemmego/privacy/index.html` resolve. Rendering checked at
desktop and at a true 390px mobile viewport.

Marketing URL is optional. If you want one, `https://github.com/justintormey/lemme-go`
is honest and already public; there is no LemmeGo marketing site.

---

## What to expect

- Beta App Review usually returns in 24 to 48 hours and is lighter than full App
  Review, but a human does open the app. The "how to test without an NFC tag"
  paragraph above is the difference between one round and a rejection.
- Once a build in a version is approved, later builds of the **same** version
  usually reach external testers without another review. A new version string
  starts the process again.
- External builds expire **90 days** after upload.
- Up to 10,000 external testers.
- Build numbers must increase within a version. This build is 1.2.0 build 1; the
  next upload of 1.2.0 must be build 2.

## Before you flip it on

Status as of 2026-09-02, version 1.2.0.

**Done, and these were blockers.**
- **Family Controls distribution entitlement confirmed granted.** Archive and
  App Store export both verified end to end.
- **`DEVELOPMENT_TEAM` was empty**, so the project could not archive at all. Set
  to `5Y8S56DTEH`.
- **Screen Time authorization bug.** iOS 26.4 added
  `AuthorizationStatus.approvedWithDataAccess`, which fell into the app's
  `@unknown default` and was read as unauthorized. On current iOS the app would
  have refused to lock for users who had granted permission. Fixed.
- **Emergency unlock reset a day early.** The week boundary resolved a Sunday to
  the *following* Monday, so the five-per-week budget refilled on Sunday. Fixed.
- **The test suite never ran.** The shared scheme's `<Testables>` block was
  empty, so `Cmd+U` reported success while executing zero tests. Wired up; 46
  tests now run, and doing so is what surfaced the week-boundary bug.
- **Privacy manifest added.** The app uses UserDefaults, a required-reason API.
  Without `PrivacyInfo.xcprivacy` the upload draws an ITMS-91053 notice.
- **Export compliance declared**, so uploads stop prompting.

**Judgement calls left to the owner.**
1. **Device QA has not happened.** Everything above was verified by building,
   archiving, exporting and running the unit suite. Nothing has run on an
   iPhone. NFC cannot be tested any other way, and the two headline fixes are
   both in code paths that only execute on a device with Screen Time granted.
2. **Unlimited sessions are genuinely one-way** without the tag. Five emergency
   unlocks a week is the only relief valve. Worth deciding whether a first
   round of external testers should see that feature at all.
