# Apple platform notes

Apple’s current documentation confirms that a WidgetKit widget is created as a separate widget extension target: https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension.

Apple documents App Groups as the shared-container mechanism for multiple targets to access shared data: https://developer.apple.com/documentation/xcode/configuring-app-groups. Because Wallet currently has a single app target and its SwiftData store is not exposed through an App Group, adding a live Total Balance/Mine widget would require a new extension target, shared-container entitlement, and shared data export/update path. That adds signing and free-Apple-ID sideload risk, so the safe scope is to defer the live widget rather than ship a non-functional or destabilizing extension.

Apple’s quick-action documentation confirms that static Home Screen actions are declared under the UIApplicationShortcutItems Info.plist key and handled through UIApplication shortcut callbacks: https://developer.apple.com/documentation/uikit/add-home-screen-quick-actions. Wallet now uses that supported approach for five static actions.

Apple’s SF Symbols documentation describes system symbols as adaptable to San Francisco typography and weights: https://developer.apple.com/design/human-interface-guidelines/sf-symbols. Wallet now uses the native `indianrupeesign` symbol beside the shared numeric formatter instead of a standalone Unicode glyph in visible SwiftUI amount components.

## App icon correction notes

Apple’s current app-icon documentation says iOS/iPadOS support Light, Dark, and Tinted app-icon styles and that a single 1024×1024 image can generate icon variations: https://developer.apple.com/documentation/xcode/configuring-your-app-icon.

The hosted Xcode 26.6 build failed in `actool` because the supplied PNGs were 1254×1254 while the asset slots were declared as 1024×1024, followed by `The stickers icon set, app icon set, or icon stack named "AppIcon" did not have any applicable content.` The images have now been normalized to 1024×1024. The remaining Contents.json schema should use explicit current AppIcon appearance variants rather than relying on an implicit base entry if actool still rejects it.

## Quick-action parser correction notes

Apple’s current quick-action documentation confirms `UIApplicationShortcutItems` is an array of dictionaries with `UIApplicationShortcutItemType`, `UIApplicationShortcutItemTitle`, and either `UIApplicationShortcutItemIconSymbolName`, `UIApplicationShortcutItemIconFile`, or `UIApplicationShortcutItemIconType`. The hosted failure occurs later in `appintentsnltrainingprocessor` while parsing the generated app `Info.plist`, after Swift compilation succeeds. This suggests the safest fix is to remove the optional category/icon metadata from the custom plist and use the documented SF Symbol key for static quick actions, while retaining the five action types.
