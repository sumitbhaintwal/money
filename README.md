# Money

An ultra-simple iOS expense tracker, bill splitter and money-habit streak. India first.

## The idea

Spending is the habit being tracked. The month grid is both the expense view and the
streak: a black dot is a clean day, a grey dot grows with what you spent, so one glance
shows the expensive days without a chart.

Essentials never break a streak. Without that exemption the metric rewards skipping a
meal or a prescription, which is the one way a no-spend streak can do real harm.

## Deliberate constraints

- **Local only.** SwiftData on device. No sync, and the ledger never leaves the phone.
- **Sign-in is stubbed.** Welcome and OTP sign-in (phone *and* email, both mandatory)
  exist as screens against `AuthService`; `StubAuthService` accepts any six digits.
  There is no backend yet, and the token lands in UserDefaults — it belongs in the
  Keychain the moment it grants anything.
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
