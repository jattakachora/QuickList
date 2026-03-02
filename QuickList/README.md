# QuickList

Smart Flutter list manager with Android Tasker integration and floating overlay popup support.

## Tasker Setup
### Option A: Plugin Action (shows in Tasker Plugin list)
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
6. Add extra `list_name` with exact list name (for example `Grocery`).
7. Run the Task.

Behavior:
- If the list exists and has items, QuickList opens the overlay popup with that list.
- If the list is missing or empty, QuickList sends broadcast reply:
  - `com.quicklist.LIST_EMPTY`
  - with extra `list_name`.

Optional success reply:
- `com.quicklist.LIST_SHOWN` with `list_name` when popup is shown.

## Android Notes
- Overlay permission is requested on first popup call.
- Required permissions and receiver declarations are already added in `AndroidManifest.xml`.
- If Tasker does not show new plugins immediately, force stop/reopen Tasker after installing the app.

A new Flutter project.
