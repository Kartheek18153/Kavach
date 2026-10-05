# Kavach — Scam Call Shield: Full Picture

Telugu-first live scam-call protection. Flutter app + Dart Shelf backend.
Put the call on speaker → tap Protect → watch the danger meter →
hang up on red → get 1930 help from the report.

---

## Part A — How the app works (plain words)

### 1. First-time setup
Open the app and go to the Family tab. Enter the name and phone number
of someone you trust (like your daughter or mother) plus a secret
family word only your family knows. Save validates everything (real
10-digit mobile, one-word safe word), cleans the number, and remembers
it on the device — even after restarts. The Home card shows Connected.
You can edit anytime or remove the contact (with confirmation).

### 2. A strange call comes in
Someone calls claiming to be CBI, police, customs, or your bank.
They say there is a case on your name, a parcel with drugs was caught,
or your account will be blocked. Put the call on speaker.
(Today you open the app yourself — it cannot yet detect the ringing
call. And without loudspeaker the app physically cannot hear anything.)

### 3. You tap Protect
On the Home screen, tap the big Protect button. The app jumps to the
Live screen and starts a real listening session (green LIVE badge —
amber DEMO means a practice script is playing). A round meter shows the
danger level and a moving wave shows it is listening. Words appear as
the call goes on; if typing is easier, type what you hear into the box.

### 4. The app watches for tricks
As the caller talks, the app checks every line against 7 trick groups
(fake officers, threats, secrecy, rushing, OTP/PIN asks, screen-share
apps, money moves) — whole words only, so "spinning" never counts as
"PIN". Each new trick pushes the meter higher; repeated pressuring
adds up too. Two killer combos (authority + OTP/money, secrecy + money)
jump straight to red. The safe word calms it down. Green = safe,
yellow = be careful, red = danger — with reasons in your language.

### 5. Red alert
If it turns red, the phone vibrates and a beeping alarm loops while a
full-screen red overlay takes over: cut the real phone call FIRST, then
tap below. It tells you why in your language, offers one-tap SMS to
your trusted person (message in your language), and an "I hung up"
button that wipes the transcript and opens the report. New tricks after
dismissing re-raise the alarm. Nothing is ever auto-sent — the warning
banner says "warn your family now," honestly.

### 6. After the call
You land on the Report screen. It shows what kind of scam it was, the
danger score, and why it was flagged — plus whether this was a live
call or a practice demo, and whether the family SMS actually went out.
It gives you a safety list (never share OTP, never install such apps,
never send money on a call). The "how this scam works" card matches
the actual scam type (digital-arrest, screen-share, or OTP fraud).
If money was involved, one tap calls 1930 (the fraud helpline) and
another opens the cybercrime website. You can copy the report or share
it straight to WhatsApp/family/police. Below sits the list of your
past scans — tap any to re-open it.

### 7. Next time
Home greets you with a protection scoreboard (live scams caught this
month, worst risk) and a tappable last-scan card that jumps to its
report. Fresh installs get a 2-minute starter card: set up family, then
practice with a demo. Past scans can be cleared with one confirm. So
next time a suspicious call comes, you just tap Protect again.

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
- Today this step is manual + simulated: no call detection exists, and
  speaker mode is instructions only with nothing verifying it.
- `READ_PHONE_STATE` / `READ_CONTACTS` are declared in the manifest but
  no code uses them yet.
- To work properly it needs: Android ring detection with a prompt,
  auto-finish on call end, and a speaker-route check that nudges the
  user onto loudspeaker (speaker-off = the mic hears nothing = the
  meter lies green). iPhones can never do this automatically — manual
  + typed path is the permanent fallback there.

### Step 3 — Protect + live start (BUILT, tested)
- Protect starts a REAL session: empty transcript, timer running,
  backend session opened, green LIVE badge. Never auto-finishes — only
  stop/reset/hang-up ends it.
- Demo scripts are explicit buttons with an amber DEMO badge and can
  take over mid-session cleanly. Decided: keep demos until mic
  streaming lands (then strip or gate as practice mode) — today the
  demo is the only way to see the full journey.
- Mic permission asked on Protect; denial runs everything anyway.
- Tests: `test/session_mode_test.dart` — real mode stays live, demos
  flagged, typed words score inside a real session.

### Step 4 — Trick detection + meter (BUILT, tested)
- Whole-word matching both sides (`wordHit`/`_wordHit`, KEEP IN SYNC):
  letters beside a keyword disqualify it; digits/symbols may touch, so
  ₹50,000 still hits. Demo scripts score exactly as before.
- Repeat escalation: urgency/threat repeats +5 each, capped +20/call
  (server `repeatBonus` field, local `_repeatBonus` mirror).
- First-hit points, hard-trigger floor (85), safe-word −20 unchanged.
- Tests: backend boundary cases + full router session test
  (10 → 15 → capped 30); app typed "spinning" stays 0, repeated
  "immediately" climbs 10 → 15.

### Step 5 — Red alert + SMS + hang-up (BUILT, verified static)
- Honest banner ("Danger — warn your family right now"), cut-first
  numbered steps on the overlay, SMS body in the app language
  (EN/TE/HI with type + risk), re-alert on genuinely new tricks,
  looping beep-beep alarm (`assets/alert_beep.wav`, stops on dismiss /
  hang-up / session end, player disposed with screen).
- Real-device checklist: same-Wi-Fi backend via `--dart-define`,
  grant mic, demo → overlay + vibration + sound, SMS composer in each
  language, hang-up stops sound instantly, offline/airplane still
  works via local engine.

### Step 6 — After-call report + 1930 help (BUILT, tested)
- Past-scans list on the Report tab (tap any to re-open, Latest button
  to return); history persists demo origin + SMS flag.
- Learning card matches the scam type (arrest / screen-share / OTP /
  generic fallback), EN/TE/HI.
- Share sheet (`share_plus`) next to Copy for WhatsApp/family/police.
- Honest verdict line: live-vs-demo origin + SMS sent vs not.
- Test: history keeps latest 20 newest-first, survives reload.

### Step 7 — Memory for next time (BUILT, tested)
- Home scoreboard: live scams caught this month (demos excluded) +
  worst monthly risk, pure local math over stored history.
- Tappable last-scan card jumps to its report; practice-demo entry
  point and family-setup shortcut on Home; first-run starter card only
  on fresh installs (no family + no scans).
- Clear-history with confirm on the Report tab; also clears the
  in-memory latest so Home never shows a ghost.
- Tests: scoreboard counts live-this-month only, first-run card
  shows/hides correctly.

### Key Q&A decisions recorded
- **AI or not:** decided NO. Scammer controls the transcript (spoken
  prompt-injection), cloud AI breaks the never-uploads promise, needs
  internet/money/latency, and there are no live words to judge yet.
  Rule engine stays the core; model at most an opt-in second opinion
  later that can only raise risk.
- **Better intent without AI:** ranked — (1) contacts + spam-number
  reputation, (2) script-stage sequence detection, (3) tougher matching
  (built as Step 4), (4) safe-word challenge flow, (5) carrier/crowd
  signals.
- **Family info storage:** yes, saved on-device (SharedPreferences /
  UserDefaults), loaded before the UI shows, covered by round-trip test.
- **SMS to the saved number:** frontend-only via the system SMS
  composer (`sms:` link, prefilled number + warning text). Needs: a
  saved valid number, the `url_launcher` plugin (present), a real phone
  with SIM, and the user tapping Send. No extra permission, no carrier
  approval, nothing to register.
- **Backend sending:** nothing. The backend never sees the number and
  sends nothing — the Telegram path was fully removed.
- **Hearing without loudspeaker:** not reliably possible on a normal
  phone. Call audio lives in a private channel apps can't tap; the
  call-recording setting captures silence on almost all phones unless
  rooted. Speaker + mic is the only universal method.

---

## Part C — What the project has now (features)

- **4-tab app** (Home / Live / Family / Report) with floating pill nav,
  EN/తె/हिं throughout, icy-blue theme, glass cards.
- **Live protection:** real LIVE sessions + clearly-badged practice
  demos, danger gauge 0–100 (Safe 0-30 / Caution 31-60 / Danger 61+),
  waveform, transcript bubbles, bilingual verdict card, typed fallback.
- **Scoring engine** (mirrored app + backend): 7 keyword groups,
  whole-word matching, repeat escalation capped +20, hard-trigger 85,
  safe-word −20. Parity + boundary + cap tests lock it.
- **Stateful backend sessions** (`start` / `score` / `end`, safeWord
  aware) with offline local fallback; sessions pruned (30-min TTL,
  cap 500). Point app via `--dart-define=KAVACH_API=`.
- **Family:** validated + normalized + persisted contact, safe word,
  Connected badge, SMS fallback, remove-with-confirm.
- **Red alert:** vibration + looping alarm, cut-first overlay,
  localized SMS, re-alert on new tricks, honest wording, private
  transcript wipe on hang-up.
- **Report:** tap-to-dial `tel:1930`, external cybercrime portal link
  (clipboard fallback), copyable + shareable summary, per-scam learning,
  past-scans browser, checklist.
- **History:** last 20 reports persisted with origin + SMS flag, last
  result restored on launch, browsable + clearable from the Report tab.
- **Home memory:** monthly scoreboard (live dangers, worst risk),
  tappable last scan, first-run starter card.
- **Permissions:** mic requested on Protect (runs regardless);
  Android mic/phone-state declarations + iOS mic strings present.
- **Privacy:** no recording; transcript cleared on hang-up.
- **Tests:** app 19/19 green, backend 9/9 green; both analyzers clean.

## Still manual / future
Mic streaming (typed fallback only); SMS needs the user tapping Send;
Step-2 call detection + speaker check unbuilt; stock icon/splash/version.
iOS can never auto-detect calls.

## Build log (one commit at a time)
1. `f6a7214` Remove Telegram alerts from backend
2. `f292fef` Backend: drop alert route, add safe-word scoring + session prune
3. `822344e` Drop Telegram family setup, add SMS + typed-input strings
4. `0e0c987` Wire backend sessions, safe-word scoring, SMS fallback,
   history + typed input
5. `902498c` Report tap-to-call 1930 + portal links via url_launcher
6. `787da92` Docs README rewrite, Kavach app label, mic permissions
7. `206411b` Step 1 store: validation, normalization, persistent Connected
8. `bd73e34` Step 1 UI: validation, guidance, remove contact
9. `b6f1c2b` Step 1 tests
10. `02971ac` Step 3: real-mode LIVE session + DEMO badge
11. `0ca99dc` Step 4: backend boundaries + repeats
12. `92bc7b2` WORKFLOW.md full picture (v1)
13. `1ee1ea3` Step 5 red-alert overhaul + `74dc3ff` WORKFLOW v2 (pushed)
14. Step 6 (report history, per-scam learning, share, honest details) —
    6 commits, code pushed.
15. Step 7 (scoreboard, tappable last scan, clear history, first-run) —
    5 commits, code pushed; doc update here.
