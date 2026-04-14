# I Built an iPhone App That Physically Locks Your Phone With an NFC Sticker

*Published on justintormey.com — drafted for WordPress*

---

Every focus app I've tried has the same fatal flaw: you can just... open it and turn it off. One tap, and all the friction you were counting on disappears. Willpower apps that rely on willpower aren't solving the problem.

I wanted something different. I wanted a *commitment device* — something that made breaking focus feel genuinely inconvenient, not just mildly annoying.

The result is **LemmeGo**: an iOS app that uses a cheap NFC sticker to lock your phone. Tap the sticker to start a focus session. Your selected apps get blocked. To unlock before the timer runs out, you have to physically tap that sticker again. No sticker, no unlock.

The code is open source: [github.com/justintormey/lemme-go-app](https://github.com/justintormey/lemme-go-app)

---

## Why NFC?

The insight is about physical separation. If you put your NFC sticker on your desk, your bookbag, your car dashboard — anywhere that isn't your pocket — then unlocking your phone becomes a deliberate physical act. You have to get up, walk over, and tap. That's enough friction to break the automatic "check my phone" loop that kills most focus sessions.

This concept isn't new. A product called [Brick](https://www.thebrick.app/) pioneered it and sells physical NFC "bricks" specifically for this purpose. LemmeGo is my take on the same idea: fully open source, buildable from scratch, no subscription.

The app works with any standard NFC tag — the NTAG213 stickers you can buy for a few cents each on Amazon are perfect. You register the tag in the app, set a duration, and tap.

---

## How It Works

The core flow is straightforward:

1. **Grant Screen Time permission** — required on first launch; this is what enables actual app blocking
2. **Select apps to block** — pick anything from social media to games to email
3. **Register an NFC tag** — hold your phone to the sticker, give it a name
4. **Set a duration** — hours, minutes, and seconds via a wheel picker; or toggle "Unlimited" for indefinite lock
5. **Tap the sticker** — lock session starts, apps get blocked
6. **Tap again to unlock** — or wait for the timer to expire

There's also a **"Lock Now"** button for sessions where you want to start without NFC (maybe the sticker is already across the room). You still need the sticker to unlock early — the commitment stays intact.

**Emergency unlock** exists because you should never be truly trapped: 5 uses per week, resetting every Monday. Enough to handle genuine emergencies; scarce enough to mean something.

---

## The Tech Stack

The app is **100% native iOS**: Swift, SwiftUI, and nothing else. No third-party dependencies whatsoever — just Apple frameworks.

**CoreNFC** handles the sticker scanning. The iPhone reads the tag's unique hardware identifier, which gets stored locally. When you tap to unlock, the app verifies it's the same tag that started the session.

**FamilyControls + ManagedSettings** (Apple's Screen Time API) does the actual app blocking. This is the interesting part.

### The Screen Time API Is Surprisingly Powerful

Apple's Screen Time framework lets apps create "shields" — system-level blocks that prevent users from opening selected apps or websites. Unlike a UI lock (which just overlays a screen), these shields are enforced by the OS. If the LemmeGo app is killed, the blocks stay active. If the phone restarts, the blocks stay active. The shield persists until the app explicitly lifts it or the session expires.

I use a **named `ManagedSettingsStore`** (`"LemmeGoShields"`) to ensure persistence across process restarts. This was a key architectural decision — anonymous stores get cleaned up; named stores survive.

### The PropertyListEncoder Bug

Here's a fun one: early versions stored the user's app selection using `JSONEncoder`. This seemed obvious. It wasn't.

Apple's `FamilyActivitySelection` type — the object that holds which apps you've chosen to block — contains *opaque tokens* for each app. These tokens are not regular data. They can't survive JSON serialization. Encoding them with `JSONEncoder` produced corrupted data that failed to decode correctly.

The fix was switching to `PropertyListEncoder`, which handles Apple's opaque types correctly. A migration path handles any legacy JSON data still sitting in `UserDefaults`.

This bug was subtle and took real debugging to find. It's the kind of thing that doesn't appear in documentation — you discover it by watching your app silently fail to block anything.

---

## Getting Apple's Approval

Here's the thing about the Screen Time API: **you can build with it freely during development**, but to distribute via TestFlight or the App Store, you need explicit approval from Apple.

The entitlement is called **Family Controls Distribution**. You submit a request explaining your use case at `developer.apple.com/contact/request/family-controls-distribution`. Apple reviews it manually.

My mental model going in was: this will take weeks, involve back-and-forth, maybe get rejected. The Screen Time API is sensitive — it's the same API used by parental control apps — and I was braced for scrutiny.

**It was fast.** Approval came within a few days. I described LemmeGo honestly: a self-directed focus tool, not a parental control, no monitoring of usage data, the user fully controls their own blocking rules. Apple seemed satisfied with that. The response was straightforward approval with no follow-up questions.

A few things probably helped:
- The use case was clearly *self-directed* (no remote control, no monitoring of another person)
- The app doesn't collect or transmit Screen Time data
- The README and app description were explicit about what the API is and isn't used for

If you're building anything with the Screen Time API: apply early, be transparent about your use case, and emphasize user autonomy. The process is smoother than the documentation makes it sound.

---

## What I'd Do Differently

**`LockManager` got too big.** It handles session lifecycle, the countdown timer, UserDefaults persistence, shield orchestration, and lifecycle event observation. It should be split — a `SessionPersistence` layer at minimum. I know what it should look like; I just didn't refactor in time.

**String literal keys everywhere.** All UserDefaults access uses raw string keys scattered across files. One centralized key registry would have made this much easier to maintain and test.

**No structured logging.** The app is full of `print()` statements. Fine for development, insufficient for debugging issues in the field.

None of these are showstoppers, but they're the kinds of decisions that compound. If I were starting from scratch, I'd build the persistence layer first.

---

## A Note on Bypass Methods

LemmeGo works through friction, not force. You can bypass it by going into iOS Settings and disabling Screen Time, revoking the app's permission, or deleting the app entirely.

**This is intentional.** iOS doesn't allow apps to truly lock users out of system settings — and it shouldn't. The goal of LemmeGo is to make checking your phone feel like a deliberate choice, not an impossibility. If you're determined to override the lock, you can. But you'll feel it, and that feeling is the point.

The one bypass I didn't build in intentionally: changing the system clock forward. iOS apps can't reliably detect this. It's enough friction on its own that it tends to break the habit loop anyway.

---

## Building Without Being an Engineer

I'm not a software engineer. LemmeGo was built with a lot of AI assistance — Claude, mainly — working through each feature iteratively. The architecture decisions, debugging sessions, and review cycles all involved AI collaboration.

What I found: the hardest part wasn't writing code. It was *scoping*. Knowing when the app was done enough to ship. Knowing which bugs were worth fixing before release versus documenting as known issues. Knowing when a refactor was necessary versus gold-plating.

Those are product decisions, and they don't get easier with AI assistance. If anything, they get harder — because you can always build more.

---

## Try It

The full source is at **[github.com/justintormey/lemme-go-app](https://github.com/justintormey/lemme-go-app)**. You'll need an Apple Developer account, Xcode, and a physical iPhone (NFC doesn't work in Simulator). NTAG213 stickers are the easiest tags to use — a 10-pack from Amazon runs about $7.

If you're waiting for TestFlight access, keep an eye on this blog. The Family Controls Distribution approval is in hand; the TestFlight build is close.

If you fork it or build something with it, I'd genuinely like to know.

---

*LemmeGo is MIT licensed. No data collected. No network requests. Everything stays on your device.*
