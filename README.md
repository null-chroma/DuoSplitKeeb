# Duo Split Keyboard

A custom iPhone keyboard for the iPhone Duo's unfolded screen. It copies the built-in split
keyboard with two changes:

- **Each half sits against its own edge of the screen.** The built-in keyboard leaves about 1.5
  key-widths of empty space on each side. This one doesn't, so the middle keys (T, G, V on the
  left; Y, G, H, V, B on the right) are easier to reach with your thumbs.
- **It's always split.** There's no split/merge button and no three-dot menu.

Everything else was measured from a screenshot of the built-in split keyboard:

- **Key size:** one key plus its gap is 6% of the screen width, and the gap is 19% of that.
- **Rows:** the same key positions in each row, including the extra G and V that start the right
  half's middle and bottom rows.
- **Look:** flat gray keys with no shadows, a return-arrow key, and keys that light up when
  pressed instead of showing a pop-up.

When the phone is folded (narrow screen), the keyboard switches back to the normal full-width
iPhone layout. You can change this to "Always" or "Never" in the app.

## What's included

| | |
|---|---|
| Layout | QWERTY letters (with the extra G and V on the right half), 123 numbers and #+= symbols |
| Keys | Shift (double-tap for caps lock), delete with key repeat, globe (tap to switch keyboards, hold for the list), return key that changes to go / search / send / done / … in the same color as the system key |
| Feel | Keys light up when pressed (pop-ups are optional), hold for accents (é, ñ, ü …), hold the space bar to move the cursor, slide your finger to change keys, fast typing with two thumbs |
| Text | Suggestion bar, autocorrect (press delete right after it to undo), your Text Replacements, auto-capitalization, double-space for "." |
| Look | Light and dark mode, the standard key click sound, optional haptics |

## Settings (in the Duo Split app)

- **Distance from screen edge**: how far the outer keys are from the side edges (default 4 pt).
- **Bottom corner clearance**: moves only the bottom row inward, so 123 and return aren't cut
  off by the screen's rounded corners (default 16 pt).
- **Key size**: 100% matches the built-in split keyboard. Smaller keys make each half narrower,
  which brings the middle keys closer to your thumbs.
- **Key height**
- **Split keyboard**: When unfolded (default) / Always / Never
- **Suggestion bar** and **key pop-ups**: the built-in split keyboard has neither, so turn the
  bar off if you want it to look the same. Autocorrect still works without the bar.
- Auto-Correction, Auto-Capitalization, the "." shortcut, haptics

The app has a test text field. Settings apply to the open keyboard right away, so you can
adjust them while you type.

## Install on your phone

You need a Mac with **Xcode 16 or newer**. A free Apple ID works for signing.

1. Open `DuoSplitKeeb.xcodeproj` in Xcode.
2. Open `Config/Signing.xcconfig` and set:
   - `BASE_BUNDLE_ID` to something unique, such as `com.yourname.duosplitkeeb`
   - `DEVELOPMENT_TEAM` to your Team ID. You can also leave it empty and choose your team under
     *Signing & Capabilities* for both the **DuoSplitKeeb** and **Keyboard** targets.
3. Connect the phone, select it as the run destination, and press ▶︎ Run.
4. On the phone, go to **Settings → General → Keyboard → Keyboards → Add New Keyboard…** and
   choose **Duo Split**.
5. Tap **Duo Split** in that list and turn on **Allow Full Access**. The keyboard needs this to
   read the settings from the app (and for haptics). It has no network code.
6. In any text field, hold the 🌐 key and pick Duo Split.

## Things iOS doesn't allow third-party keyboards to do

These limits apply to every custom keyboard, not just this one:

- iOS always switches to the system keyboard for password fields and phone-number pads.
- No dictation microphone, and no emoji key. Use the globe key to switch to the emoji keyboard.
  The space bars also cover the spots where those keys sit on the built-in keyboard.
- Suggestions come from Apple's public spell checker, so they're good but not as smart as the
  system keyboard's predictions.

## Code layout

```
App/        The settings app (SwiftUI)
Keyboard/   The keyboard extension
  KeyLayout.swift              key rows for each half, plus the accent lists
  KeyboardView.swift           layout (split or joined), drawing, and touch handling
  KeyboardViewController.swift text input: shift, autocorrect, the return key, and so on
  KeyPopups.swift              key pop-up and accent picker
  SuggestionBar.swift, TextPredictor.swift
  KeyboardTheme.swift          colors (tweak these if anything looks off next to the system keyboard)
Shared/     Settings shared by the app and the keyboard (App Group)
Config/     Info.plists, entitlements, and Signing.xcconfig
```
