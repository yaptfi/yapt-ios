# Gemini's Plan for Yapt (iOS)

This document outlines my understanding of the Yapt iOS project and my plan for completing the upcoming work. It is based on the Product Requirements Document (`yapt-ios-prd.md`), `claude.md`, and the project's file structure.

## Project Overview

- **Project:** Yapt for iOS
- **Goal:** A mobile dashboard for DeFi yield tracking.
- **Tech Stack:** Swift, SwiftUI, MVVM, Combine.
- **Backend:** Existing Fastify/TypeScript API.

## Current Status

Phases 1 and 2 are complete.

- **Phase 1 (Auth & Dashboard):** Implemented. Users can log in with passkeys and view their portfolio summary, positions, and wallets.
- **Phase 2 (Add Wallet & Discovery):** Implemented. Users can add new wallets via address or ENS, and see real-time discovery progress using SSE.

My task is to implement Phase 3.

## Phase 3: Notifications

The goal of Phase 3 is to add support for configurable notifications. This will be broken down into two sub-phases as per the PRD.

### Phase 3a: In-App Notifications & Settings

1.  **Notification Settings Model:**
    - Create a new Swift `struct` or `class` to model the notification settings from `GET /api/notifications/settings`.
    - This will likely go into `Yapt/Core/Models/`.

2.  **Notification Settings View:**
    - Create a new view, likely named `NotificationSettingsView.swift` inside `Yapt/Features/Settings/`.
    - This view will display the user's notification settings.
    - It will contain UI elements (toggles, text fields, pickers) to modify the settings.

3.  **Notification Settings ViewModel:**
    - Create a `NotificationSettingsViewModel.swift` in `Yapt/Features/Settings/`.
    - It will fetch the current settings using a new method in an appropriate service (e.g., a new `NotificationService`).
    - It will handle updating the settings via `PUT /api/notifications/settings`.

4.  **Networking for Notification Settings:**
    - Extend the `APIClient` or create a new `NotificationService` to handle:
        - `GET /api/notifications/settings`
        - `PUT /api/notifications/settings`

5.  **Notification History Feed:**
    - Create a view to display the notification history, likely `NotificationHistoryView.swift`. This could live in a new `Yapt/Features/Notifications` directory.
    - Create a `NotificationHistoryViewModel.swift` to fetch data from `GET /api/notifications/history`.
    - The API calls for this will be added to the new `NotificationService`.

6.  **In-App Banners:**
    - Implement a system to show in-app notification banners or toasts when the app is active. This could be a custom SwiftUI view that appears from the top of the screen.

### Phase 3b: Push Notifications (APNs)

This phase will be implemented once the backend supports APNs.

1.  **APNs Registration:**
    - In `YaptApp.swift`, request authorization for user notifications.
    - On success, register for remote notifications to get the device token.

2.  **Device Token Handling:**
    - Create a service method (e.g., in `NotificationService`) to send the device token to the backend: `POST /api/notifications/devices`.
    - Handle token updates and unregistration (`DELETE /api/notifications/devices/:deviceId`).

3.  **Handling Incoming Notifications:**
    - Implement `AppDelegate` methods (or the SwiftUI equivalent) for handling incoming push notifications in the foreground and when the app is launched from a notification.
    - Navigation to the relevant screen when a notification is tapped.

## My Notes & Open Questions

- The `codebase_investigator` tool failed, so I'm working with less information than I'd like. I will need to be careful and read files as I go to understand the existing patterns.
- I will start with Phase 3a.
- The PRD mentions `SettingsView.swift`. I will check if I should add the notification settings there or create a new view and navigate to it. Given the number of settings, a separate view seems appropriate.
- I need to decide where to create the `NotificationService`. Looking at the structure, a new file `Yapt/Features/Notifications/NotificationService.swift` might be a good place. However, given `PortfolioService` is in `Dashboard`, maybe it should be in `Settings`. I'll look at existing services to decide. `WalletService` is in `Wallets`, so `NotificationService` in a new `Notifications` feature folder seems correct.
- From PRD: "Notifications as a section under Settings in Phase 3 or its own tab when push lands." - I'll start by adding a navigation link from `SettingsView` to the new notification settings view.
- I will need to create new model files for notifications, like `NotificationSetting.swift` and `Notification.swift` in `Yapt/Core/Models/`.

This plan should be a good starting point. I will update it as I learn more about the codebase.
