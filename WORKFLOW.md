# Kavach — Scam Call Shield: Full Picture

Telugu-first live scam-call protection. Flutter app + Dart Shelf backend.
Put the call on speaker → tap Protect → watch the danger meter →
hang up on red → get 1930 help from the report.

---

## Part A — How the app works (plain words)

### 1. First-time setup
Open the app and go to the Family tab. Enter the name and phone number
of someone you trust (like your daughter or mother) plus a secret
family word only your family knows. Save it once — the app remembers it
on the device, even after restarts.

### 2. A strange call comes in
Someone calls claiming to be CBI, police, customs, or your bank.
They say there is a case on your name, a parcel with drugs was caught,
or your account will be blocked. Put the call on speaker.
(Today you open the app yourself — it cannot yet detect the ringing call.)

### 3. You tap Protect
On the Home screen, tap the big Protect button. The app jumps to the
Live screen and starts listening with you. A round meter shows the
danger level and a moving wave shows it is listening. Words from the
call appear on screen as the call goes on. If typing is easier, you can
also type what you hear into the box and the app checks that too.

### 4. The app watches for tricks
As the caller talks, the app looks for warning signs: claiming to be
an officer, threatening arrest, telling you to keep it secret, rushing
you, asking for OTP or PIN, asking to install an app that shares your
screen, or asking to send money. Each trick pushes the meter higher —
green means safe, yellow means be careful, red means danger. If the
caller says your family secret word, the meter calms down because it is
likely really family.

### 5. Red alert
If it turns red, the whole screen turns red with big words telling you
to hang up right now, and it tells you why in your language. It
vibrates to get your attention. You can tap one button to send your
trusted person an SMS warning, then tap that you hung up.

### 6. After the call
You land on the Report screen. It shows what kind of scam it was, the
danger score, and why it was flagged. It gives you a safety list
(never share OTP, never install such apps, never send money on a call).
If money was involved, one tap calls 1930 (the fraud helpline) and
another opens the cybercrime website. You can copy the whole report to
share with family or police.

### 7. Next time
The app remembers your last check and your family details, so next time
a suspicious call comes, you just tap Protect again.

The whole loop: set family once → tap Protect on speaker →
watch the meter → hang up on red → get help from the report.

---

## Part B — Step deep-dives

### Step 1 — Family setup (BUILT, tested)
- 3 fields: trusted name, mobile number, family safe word. Save
  validates: name 2+ letters, phone must be a real 10-digit Indian
  mobile, safe word optional but one word with 4+ letters if given.
  Errors show under each field in EN/TE/HI.
- Phone is auto-cleaned before storing (+91 / 91 / leading 0 / spaces /
  dashes stripped → 10 digits). Safe word is uppercased.
- Stored on-device via SharedPreferences (survives app close and
  reboots; wiped only by uninstall or the Remove button). Home's
  "Connected" badge is derived from stored data, so it survives
  restarts too.
- Safe-word guidance text explains the idea (family-only word, ask for
  it on doubt calls, hang up if they can't say it).
- Edit by changing + re-saving; Remove contact asks for confirmation
  and warns alerts stop until you save again.
- Tests: `test/guardian_test.dart` — normalization, validation,
  display format, save→reload round-trip, clear wipes.

### Step 2 — The call + speaker (ELABORATED, not yet built)
- Today this step is manual + simulated: no call detection exists, the
  "call" is a built-in demo script, and speaker mode is instructions
  only ("keep it on speaker") with nothing verifying it.
- `READ_PHONE_STATE` / `READ_CONTACTS` are declared in the manifest but
  no code uses them yet.
- To work properly it needs: Android ring detection with a prompt,
  auto-finish on call end, and a speaker-route check that nudges the
  user onto loudspeaker (speaker-off = the mic hears nothing = the
  meter lies green). iPhones can never do this automatically — manual
  + typed path is the permanent fallback there.

### Key Q&A decisions recorded
- **Family info storage:** yes, saved on-device (SharedPreferences /
  UserDefaults), loaded before the UI shows, covered by round-trip test.
- **SMS to the saved number:** frontend-only via the system SMS
  composer (`sms:` link, prefilled number + warning text). Needs: a
  saved valid number, the `url_launcher` plugin (present), a real phone
  with SIM, and the user tapping Send. No extra permission, no carrier
  approval, nothing to register — it is like typing the SMS yourself.
  (Normal SIM SMS charges may apply.)
- **Backend sending:** nothing. The backend never sees the number and
  sends nothing — the Telegram path was fully removed.
- **Hearing without loudspeaker:** not reliably possible on a normal
  phone. Call audio lives in a private channel apps can't tap; the
  call-recording setting captures silence on almost all phones unless
  rooted. Speaker + mic is the only universal method — hence the
  speaker check matters.

---

## Part C — What the project has now (features)

- **4-tab app** (Home / Live / Family / Report) with floating pill nav,
  EN/తె/हिं throughout, icy-blue theme, glass cards.
- **Live protection:** danger gauge 0–100 (Safe 0-30 / Caution 31-60 /
  Danger 61+), waveform, transcript bubbles, bilingual verdict card,
  demo scam + normal scripts, type-what-you-hear box, red HANG UP
  overlay + vibration + SMS button.
- **Scoring engine** (mirrored app + backend): 7 keyword groups with
  hard-trigger floor at 85 and safe-word −20. Parity test locks the
  groups.
- **Stateful backend sessions** (`start` / `score` / `end`, safeWord
  aware) with offline local fallback; sessions pruned (30-min TTL,
  cap 500). Point app via `--dart-define=KAVACH_API=`.
- **Family:** validated + normalized + persisted contact, safe word,
  Connected badge, SMS fallback, remove-with-confirm.
- **Report:** tap-to-dial `tel:1930`, external cybercrime portal link
  (clipboard fallback), copyable summary, checklist, learning card.
- **History:** last 20 reports persisted, last result restored on launch.
- **Permissions:** mic requested on Protect (demo runs regardless);
  Android mic/phone-state declarations + iOS mic strings present.
- **Privacy:** no recording; transcript cleared on hang-up.
- **Tests:** app 12/12 green, backend 7/7 green; both analyzers clean.

## Still manual / future
Live audio is typed fallback (no mic streaming yet); SMS needs the user
tapping Send; no call-history screen (only last result shown); stock
icon/splash/version. iOS can never auto-detect calls.

## Build log (one commit at a time)
1. `f6a7214` Remove Telegram alerts from backend
2. `f292fef` Backend: drop alert route, add safe-word scoring + session prune
3. `822344e` Drop Telegram family setup, add SMS + typed-input strings
4. `0e0c987` Wire backend sessions, safe-word scoring, SMS fallback,
   history + typed input
5. `902498c` Report tap-to-call 1930 + portal links via url_launcher
6. `787da92` Docs README rewrite, Kavach app label, mic permissions
+ Step-1 family hardening (validation, normalization, guidance,
  Connected-after-restart, clear-with-confirm, guardian tests) —
  implemented, uncommitted.
