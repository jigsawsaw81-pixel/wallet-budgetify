# Wallet Native iOS Implementation Standards

This document establishes the engineering and design standards for the Wallet app, ensuring it meets Apple’s strict requirements for a first-party feel on iOS. It is grounded in the current Apple Human Interface Guidelines (HIG) and SwiftUI documentation [1] [2].

## Liquid Glass and Materials

Apple defines Liquid Glass as a distinct functional layer for controls and navigation, not a decorative effect for content [2]. Standard SwiftUI components—such as tab bars, navigation bars, and sheets—automatically adopt Liquid Glass and dynamically adapt to overlap and focus.

For Wallet, this means:
- Do not apply custom glass backgrounds or neon glows to content cards; use standard semantic materials (e.g., `.regularMaterial`) or subtle glass shadows instead.
- Rely on the system to render Liquid Glass in `TabView` and `NavigationStack` [3].
- When a custom floating control genuinely belongs to the functional layer, use `.glassEffect(.regular, in: .rect(cornerRadius: ...))` sparingly [4].
- Ensure the app works seamlessly across Light, Dark, and Increased Contrast modes, as Liquid Glass relies on the underlying content for its color and luminance [5].

## Navigation and Hierarchy

A tab bar is strictly for navigation among top-level sections, not for triggering actions [6]. If an action affects the current view, it belongs in a toolbar.

For Wallet, this means:
- The bottom tab bar must remain visible during top-level navigation to preserve context.
- Avoid overflow tabs; keep the number of tabs to five or fewer to prevent the "More" tab from hiding destinations.
- Use filled SF Symbols and concise, single-word labels for tab items [6].
- If a quick-entry action (like "+") is placed in the tab bar for convenience, it must be treated carefully as a shortcut affordance, not a section.

## Presentation and Modals

Sheets are intended for scoped tasks closely related to the current context [7]. Alerts interrupt the user and should be used sparingly [8].

For Wallet, this means:
- Use standard, state-driven SwiftUI sheets (`.sheet(isPresented:...)`) for all editors (transactions, accounts, groups, recurring plans) [9].
- Place a **Cancel** button on the leading edge of the top toolbar and a **Save/Done** button on the trailing edge [7].
- Provide a grabber for resizable sheets and use detents intentionally. Medium detents are for progressive disclosure; full-height sheets are for forms needing vertical space [7] [10].
- Do not stack sheets. Dismiss one before presenting another.
- Use native, centered alerts (`.alert("Title", isPresented:...)`) for irreversible destructive actions like permanent data deletion. Do not use custom floating popovers for confirmation [8] [11].

## Typography and Layout

Apple recommends system typography for legibility, hierarchy, and automatic adaptation to Dynamic Type [12]. Layouts must adapt gracefully to different device sizes, safe areas, and accessibility settings [13].

For Wallet, this means:
- Use semantic text styles (`.largeTitle`, `.title`, `.headline`, `.body`, `.subheadline`, etc.) exclusively, rather than hard-coded point sizes [12].
- Use `@ScaledMetric` only when a custom numeric display (like the hero balance) genuinely requires it.
- Ensure layouts do not clip or truncate when the user enables the largest accessibility text sizes. Stack inline items vertically if horizontal space becomes constrained [12].
- Respect safe-area insets; do not hard-code padding to avoid the Dynamic Island or Home indicator [13].
- Extend ambient backgrounds to the edges of the display, allowing the Liquid Glass functional layer to float above [13].

## Controls and Feedback

Buttons should use visual style, not size, to distinguish the preferred action [14]. Text fields should match the anticipated input size and provide clear hints and labels [15]. Motion should be purposeful and respect user preferences [16].

For Wallet, this means:
- Limit prominent buttons to one or two per view [14].
- Use `.buttonStyle(.glass)` or `.buttonStyle(.glassProminent)` for custom iOS 26+ controls, with fallbacks for iOS 17 [17].
- Use decimal keyboards and locale-aware number formatters for financial input [15].
- Keep custom animations brief, precise, and tied to state changes. Avoid animating frequently used rows unnecessarily [16].
- Provide meaningful accessibility labels and hints for all balances, actions, and navigation items [18].

## SDK and Compatibility

Xcode 26 includes the iOS 26 SDK and supports on-device debugging for iOS 15 and later [19]. Xcode 27 beta introduces the iOS 27 SDK [20].

For Wallet, this means:
- Maintain an iOS 17 deployment target for broad compatibility.
- Compile and test against the iOS 26 SDK as the stable baseline.
- Gate iOS 26+ specific APIs (like `.glassEffect`) behind `#available(iOS 26.0, *)` checks.
- Test the app in Xcode 27 beta to ensure forward compatibility, but do not rely on beta APIs for production builds.

---

## References

[1] Apple Developer, "Human Interface Guidelines," https://developer.apple.com/design/human-interface-guidelines
[2] Apple Developer, "Liquid Glass," https://developer.apple.com/documentation/technologyoverviews/liquid-glass
[3] Apple Developer, "Adopting Liquid Glass," https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
[4] Apple Developer, "Applying Liquid Glass to custom views," https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
[5] Apple Developer, "Color," https://developer.apple.com/design/human-interface-guidelines/color
[6] Apple Developer, "Tab bars," https://developer.apple.com/design/human-interface-guidelines/tab-bars
[7] Apple Developer, "Sheets," https://developer.apple.com/design/human-interface-guidelines/sheets
[8] Apple Developer, "Alerts," https://developer.apple.com/design/human-interface-guidelines/alerts
[9] Apple Developer, "sheet(isPresented:onDismiss:content:)," https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)
[10] Apple Developer, "presentationDetents(_:selection:)," https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:selection:)
[11] Apple Developer, "alert(_:isPresented:actions:message:)," https://developer.apple.com/documentation/swiftui/view/alert(_:ispresented:actions:message:)
[12] Apple Developer, "Typography," https://developer.apple.com/design/human-interface-guidelines/typography
[13] Apple Developer, "Layout," https://developer.apple.com/design/human-interface-guidelines/layout
[14] Apple Developer, "Buttons," https://developer.apple.com/design/human-interface-guidelines/buttons
[15] Apple Developer, "Text fields," https://developer.apple.com/design/human-interface-guidelines/text-fields
[16] Apple Developer, "Motion," https://developer.apple.com/design/human-interface-guidelines/motion
[17] Apple Developer, "GlassButtonStyle," https://developer.apple.com/documentation/swiftui/glassbuttonstyle
[18] Apple Developer, "Accessibility," https://developer.apple.com/design/human-interface-guidelines/accessibility
[19] Apple Developer, "Xcode 26 Release Notes," https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes
[20] Apple Developer, "Xcode 27 Beta 5 Release Notes," https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes
