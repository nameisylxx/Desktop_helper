# Desktop Helper

A native macOS panel that lives on your desktop. It shows today's calendar, weather, to-dos and what's due soon. The panel sits above your desktop icons and below every app window, so it shows up whenever you look at the desktop and never gets in the way.

## Features

- **Clock & date**: large time with the full date underneath.
- **Weather**: current conditions, the next 6 hours, and a 3-day forecast from [Open-Meteo](https://open-meteo.com) (free, no API key). Uses your location, or a city you pick in Settings.
- **Calendar**: a mini month view with event dots and a list of upcoming events. Reads Apple Calendar, so iCloud, Google and Exchange calendars added to Calendar.app show up too.
- **Plans & To-Dos**: open reminders grouped into Overdue / Today / Later / No Date. Check items off or add new ones right from the panel; changes sync to Reminders.app and your iPhone.
- **Due Soon**:
  - A countdown list of reminders and files due within the next N days.
  - A **file shelf**: drag PDFs or any other files in, and they appear as desktop-style icons with thumbnails. Double-click to open, drag them back out, or right-click to set a due date.
  - The shelf only stores a reference (bookmark) to each file. Nothing is copied or moved, and files are still found after you move or rename them in Finder.
- **Frosted glass look**: a pure blur of the wallpaper with no color tint. The blur strength is adjustable.
- **Menu bar controls**: show/hide the panel, lock its position and size, reset its position, refresh, open Settings.

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build & Run

```sh
brew install xcodegen          # once
xcodegen generate              # creates DesktopHelper.xcodeproj from project.yml
open DesktopHelper.xcodeproj   # then press ⌘R
```

Or from the command line:

```sh
xcodebuild -project DesktopHelper.xcodeproj -scheme DesktopHelper -derivedDataPath build build
open build/Build/Products/Debug/DesktopHelper.app
```

The `.xcodeproj` is generated and not checked in. Run `xcodegen generate` again after adding or removing source files.

On first launch macOS asks for access to **Calendars**, **Reminders** and **Location**. All three are optional: a card without access shows a button to grant it later.

## Settings

Open the menu bar icon → **Settings…**

| Tab | Options |
| --- | --- |
| General | Launch at login, days of events to show, Due Soon window, background blur |
| Weather | Use current location, fallback city search, °C / °F |
| Calendar & Reminders | Which calendars and reminder lists to show, default list for new to-dos |

## Project Structure

```
project.yml                  XcodeGen project definition
DesktopHelper/
  App/        App entry, menu bar, desktop-level panel, window blur, settings keys
  Services/   EventKit (calendar + reminders), Open-Meteo weather, location, file shelf
  Models/     Value types the views use (events, reminders, weather, shelf items)
  Views/      SwiftUI cards, file shelf, settings window
    Theme.swift   Fonts and layout grid. Change `family` to try a different typeface
  Resources/  Info.plist and entitlements
```

## Notes

- **Blur uses a private API.** The background blur comes from WindowServer's `CGSSetWindowBackgroundBlurRadius` (the same call iTerm2 uses), looked up at runtime with `dlsym`. It works even with *Reduce Transparency* turned on, which disables the standard `NSVisualEffectView` materials. Because of this private API, the app is not eligible for the Mac App Store.
- **Not sandboxed.** It runs with the Hardened Runtime but without the App Sandbox, so file bookmarks and drag-and-drop work without extra entitlements.
- **Local data**:
  - Shelf items are stored in `~/Library/Application Support/DesktopHelper/shelf.json`.
  - Preferences and the last weather result are stored in the app's `UserDefaults`.
  - Calendar and reminder data never leave EventKit.
