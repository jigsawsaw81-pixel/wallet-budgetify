# Budgetify Native iOS Design and Architecture

## Design direction

Budgetify Native is **calm, precise, and premium**. The quality bar is Apple Wallet and Apple Card: clear financial hierarchy, restrained motion, dense but breathable information, and tactile controls. The supplied blue wallet icon remains the identity anchor, while the app surface is rebuilt around a dark teal financial canvas.

| System | Decision |
|---|---|
| Heading font | SF Pro Display, semibold/heavy weights |
| Body font | SF Pro Text, regular/medium weights |
| Numeric treatment | SF Pro Rounded or monospaced digit variants for balances and totals |
| Background | `#080D12` with subtle teal/blue ambient orbs |
| Primary text | `#E8F4F8` |
| Secondary text | `#7BAABB` |
| Primary action | `#00D2C8` |
| Positive | `#10D98A` |
| Negative | `#FF5C6A` |
| Pending | `#FFB340` |
| Supporting accents | `#A78BFA`, `#60A5FA` |
| Spacing | 8pt control rhythm, 16pt card rhythm, 24pt section rhythm, 40pt screen transitions |

## Navigation model

On iPhone, the app uses a five-item tab bar: Home, Transactions, Recurring, Wallets, and Settings. Categories live inside Settings as a segmented management section rather than creating a sixth tab. On iPad, the same destinations use a sidebar-aware NavigationSplitView. Every primary control is at least 44pt high, and every scroll view includes safe-area-aware bottom padding.

## Liquid Glass model

Liquid Glass is reserved for the navigation bar, tab bar, floating quick-add control, segmented controls, compact filter chips, and modal action surfaces. The dashboard hero remains a custom high-contrast financial card instead of applying blur to the main balance. Glass surfaces use the native `glassEffect` API when available on iOS 26, and a `thinMaterial` fallback on earlier systems. The UI avoids stacking more than two translucent surfaces over one another, preventing muddied contrast and edge artifacts.

## State architecture

`BudgetifyStore` is the single observable domain store. SwiftData persists `AccountGroup`, `Wallet`, `Category`, `Transaction`, `RecurringPayment`, and `AppPreferences`. The store exposes derived balances, month summaries, due payments, cash-flow forecast, search/filter results, and import/export operations. All mutation methods validate inputs before writing, use stable UUIDs, and recalculate derived values from source data rather than caching totals.

## Screens

The Home screen has one dominant element: net worth. It includes a glass bank/cash switcher, a hero balance card, month-to-date income/expense/net metrics, today’s debit total, a quick-add button, and the latest transactions. Transactions has one dominant element: the filtered ledger, with type segments, search, date/category filters, grouped rows, edit-on-tap, and swipe-to-delete. Recurring has two clear sections: EMIs/subscriptions and fixed expenses, plus a forecast card. Wallets organizes accounts by Mine, Others, and Work, with expandable groups and transfer action. Settings manages appearance, data export/import, account deletion, and categories.

## Validation strategy

The implementation must be checked for: deterministic balance math; pending-income exclusion; transfer double-entry behavior; empty states; duplicate default records; import/export round-trip; large Dynamic Type sizes; VoiceOver labels; dark/light/system appearance; iPhone 13 safe areas; iPad split layout; keyboard dismissal; destructive-action confirmation; and no clipped or overlapping content in compact widths.
