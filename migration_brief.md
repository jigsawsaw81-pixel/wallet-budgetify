# Budgetify Native Migration Brief

## Source inventory

The supplied `budgetify.7z` contains a production React web bundle rather than an Xcode project. It includes `index.html`, PWA manifests, three PNG brand assets, a compiled `main.61061208.js`, a license file, and an embedded source map. The source map successfully recovers the first-party `App.js` and `index.js` source, alongside bundled Firebase and other dependency sources.

## Existing product scope

The app supports email/password authentication through Firebase Auth; persistent cloud data through Firestore; dashboard/home; unified transactions; wallets/accounts; recurring obligations combining EMIs and fixed expenses; settings; category management; JSON export/import; account deletion; light/dark/system theme; and a custom calculator keypad for amount entry.

The primary data collections are `accountGroups`, `wallets`, `transactions`, `categories`, `emis`, and `fixedExpenses`. Default account groups are Mine, Others, and Work. Default categories are Food, Shopping, Transport, Housing, Salary, EMIs, Subscriptions, and Other. The default wallet is Main Bank with zero initial balance.

## Existing business rules

A wallet balance equals its initial balance plus income transactions minus expense transactions, excluding pending income. Mine is split into bank and cash; Work and Others are bank-oriented. Grand total includes Mine bank plus Mine cash plus Work bank plus Others bank. Current-month income excludes pending income; current-month expense includes expenses; net profit is income minus expense. Due payments are all pending income. Cash-flow forecast equals grand total plus due payments minus all fixed-expense amounts and EMI/subscription amounts.

Transactions support expense and income types, wallet and category assignment, optional income status (Received/Pending), optional payment method, editing, deletion, quick expense creation, transfer between wallets, search by title/category, type filters, category filters, and date filters for all time/today/7 days/30 days. Transactions are grouped as Today, Yesterday, This Week, and Older.

EMIs and subscriptions store name, amount, day of month, wallet, category, active state, and type. Fixed expenses store name, amount, frequency (daily/weekly/monthly/annually), wallet, category, and active state. Settings expose system/light/dark mode, density, font-size preference, export, import, and delete-account flow. Categories and account groups are editable.

## Native rebuild direction

Personality: calm, precise, premium. Reference quality bar: Apple Wallet / Apple Card information hierarchy, without copying proprietary visuals. Typography: SF Pro Display for headings and SF Pro Text for body copy; numeric amounts should use monospaced digit variants where helpful. Palette: background `#080D12`, primary text `#E8F4F8`, secondary text `#7BAABB`, primary action `#00D2C8`, accent support colors green `#10D98A`, red `#FF5C6A`, amber `#FFB340`, purple `#A78BFA`, and blue `#60A5FA`. The supplied blue wallet icon remains the starting app identity, but the in-app system should use teal-forward Liquid Glass surfaces with strong contrast and restrained blur.

## Build constraint

The sandbox is Linux and does not provide Xcode, Apple SDKs, or code-signing certificates. Swift source and an Xcode project can be authored here, but a real `.app`/`.ipa` must be compiled and signed on macOS with Xcode and a provisioning/signing identity. The native implementation should therefore include a reproducible Xcode project and a validation checklist, then require a connected Mac or user-provided signed build environment for final IPA generation and sideloading.
