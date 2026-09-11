# Money

An ultra-simple iOS expense tracker and bill splitter. India first.

## The idea

The month grid is the app. Each day shows what it cost you, coloured by weight, so one
glance finds the expensive days without a chart.

Expenses can be marked essential — groceries, health, transport, bills — which separates
money you decided to spend from money you didn't.

## Deliberate constraints

- **Local only.** SwiftData on device. No sync, and the ledger never leaves the phone.
- **Sign-in talks to a real backend.** OTP over email, with the phone captured but
  not messaged — SMS to Indian numbers needs DLT registration. The backend lives in
  [SSS-cloud](https://github.com/sumitbhaintwal/money): Cloudflare Workers + D1.
  The bearer token is in the Keychain, and signing out revokes it server-side.
  `API_BASE_URL` is a build setting: Debug points at a local `wrangler dev`.
- **Single-player.** India is ~92% Android, so the people you split with mostly can't run
  the app. You keep the ledger; they never need to install anything. Reminders go out as
  plain messages, settlement hands off to UPI.
- **Never touches money.** Settlement is a `upi://pay` deep link. The app records what you
  tell it and holds no funds, which keeps it a personal finance manager rather than a
  regulated payment entity.
- **Pure black and white.** No hue anywhere. Liquid Glass throughout.

## Build

Requires Xcode 26+ and an iOS 26 simulator or device.

```
open SSS.xcodeproj
```

Debug builds seed a realistic month relative to today so the app opens in a working
state. Release builds start empty.
