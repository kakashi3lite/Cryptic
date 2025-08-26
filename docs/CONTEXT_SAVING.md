# Context Saving Best Practices (SwiftUI 6 + SwiftData)

This project targets iOS 18+ and uses SwiftData for local persistence. The goals are crash safety, user privacy, and zero data loss, while keeping performance snappy.

## Principles
- Reliability first: coalesce frequent edits, save on app lifecycle transitions, and handle memory pressure.
- Privacy-by-default: on-device only; file protection enabled by the OS; no analytics.
- Performance: debounce writes, avoid unnecessary context churn, and keep work on the main actor only where required.

## What’s Implemented
- `ContextSaver` actor with debounced saves and an immediate `saveNow(_)` path.
- `SaveOnScenePhase` ViewModifier that:
  - Saves on scene phase changes (inactive/background) with a background task allowance.
  - Saves on memory warnings.
  - Provides `.autosaveModelContext()` for easy opt-in.
- Content actions (`addItem`, `deleteItems`) schedule a debounced save.

## Usage
Wrap your root view with autosave:

```swift
ContentView()
  .autosaveModelContext()
```

Schedule saves after mutating operations:

```swift
modelContext.insert(object)
ContextSaver.shared.scheduleSave(modelContext)
```

## Additional Guidance
- Save cadence
  - Immediate save on leaving foreground (inactive/background)
  - Debounced saves (~750ms) during continuous editing
- Error handling
  - Catch and log save errors in DEBUG; avoid user-facing errors for benign failures
- Background work
  - Use background task allowances for final saves when app is suspended
- Future (Core Data parity)
  - If moving to Core Data: use a private writer context, merge policies (prefer store), history tracking for maintenance, and batch deletes for cleanup

## Testing Ideas
- Simulate rapid edits and verify no UI hitches
- Enter background and kill the app; ensure changes persist
- Trigger memory warnings on device and verify save path

