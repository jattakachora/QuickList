# QuickList

Smart list manager with Android Tasker integration and floating overlay popup support.

## Changes In This Version (2026-03-05)
- Added item moving between lists from the item edit sheet (`Move to list` + `Move` action).
- Added emoji support for list names, displayed as a prefix (example: `🎁 Gifts`).
- Upgraded emoji selection from fixed chips to a full emoji picker.
- Fixed bottom-sheet action buttons being hidden behind Android navigation bars in:
  - Quick Add Options sheet
  - Item Edit sheet

## APK Build Flow (GitHub Actions)
- Workflow file: `.github/workflows/build-apk.yml`
- Trigger:
  - Push to `main`
  - Manual run via `workflow_dispatch`
- Build command:
  - `flutter build apk --release --split-per-abi`
- Output artifacts:
  - Uploaded as `quicklist-apks`
  - Includes APKs from `build/app/outputs/flutter-apk/*.apk`

## Download APKs
- Latest release page: https://github.com/jattakachora/QuickList/releases/tag/latest-apk
- Quick download (always newest): https://github.com/jattakachora/QuickList/releases/latest

Included APK architectures:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM, most modern phones)
- `app-x86_64-release.apk` (x86_64 Android devices/emulators)

## Android Requirements
- Android device with overlay permission support.
- Recommended: Android 8.0+ for best background behavior reliability.
- Tasker app is required only for Tasker automation features.

## Permissions Used
- `android.permission.SYSTEM_ALERT_WINDOW`
  - Needed to show the floating overlay popup on top of other apps.
- `android.permission.FOREGROUND_SERVICE`
  - Required by Android for the overlay foreground service.
- `android.permission.FOREGROUND_SERVICE_SPECIAL_USE`
  - Required for special-use foreground service type on newer Android versions.
- `android.permission.RECEIVE_BOOT_COMPLETED`
  - Allows handling boot-complete behavior used by overlay/task automation components.

## Tasker Setup
### Option A: Plugin Action (recommended)
1. In Tasker, create/edit a Task.
2. Add `Action` -> `Plugin` -> `QuickList Action`.
3. Tap the edit icon.
4. Pick a list from the dropdown (auto-filled from QuickList lists).
5. Save and run the Task.
6. If dropdown is empty, open QuickList app once to refresh Tasker cache.

### Option B: Send Intent (manual)
1. Create a Task in Tasker.
2. Add `Action` -> `System` -> `Send Intent`.
3. Set `Action` to `com.quicklist.SHOW_POPUP`.
4. Set `Package` to `com.quicklist`.
5. Set `Target` to `Broadcast Receiver`.
6. Add extra `list_id` (preferred) or `list_name`.
7. Run the Task.

Behavior:
- If the list exists and has items, QuickList opens the overlay popup with that list.
- If the list is missing or empty, QuickList sends broadcast reply:
  - `com.quicklist.LIST_EMPTY`
  - with extras `list_id` and/or `list_name`.
- Optional success reply:
  - `com.quicklist.LIST_SHOWN` with `list_id` and `list_name`.

## Overlay Behavior
- Popup shows selected list with live check/uncheck support.
- Changes from app and popup sync through shared sync clock + refresh flow.
- Popup can be minimized to a notification and restored from notification tap.
- Back press on popup minimizes it.

## Known Android Limitation
- The system "overlay is active" foreground-service notification cannot be fully removed while overlay is running on modern Android versions.

## Android Notes
- Overlay permission is requested on first popup call.
- Required permissions and receiver declarations are added in `AndroidManifest.xml`.
- If Tasker does not show new plugins immediately, force stop/reopen Tasker after installing app.
