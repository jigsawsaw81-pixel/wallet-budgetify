# Wallet Native

Wallet is a native SwiftUI + SwiftData local-first finance app. It provides dashboard balances, credits, debits, wallet groups, recurring payments, fixed expenses, category management, reliable JSON backups, App Intents, native liquid-glass surfaces, and destructive-data safeguards. The app uses the native Unicode Indian Rupee Sign `₹` with shared Decimal-based formatting and a reusable amount component throughout the UI. The optional Home Screen extension, icon quick actions, and haptic feedback are not included.

## Open and build on macOS

Open `Wallet.xcodeproj` in Xcode. The native target and product are named `Wallet`. Select the `Wallet` scheme, choose an iPhone simulator or connected iPhone, and set a signing team only when you are performing a user-controlled signed build. The project keeps an iOS 17.0 deployment target, so it remains installable on supported older systems while also building for iOS 26 and future iOS 27 devices. The iOS 26 path has been verified on GitHub Actions with Xcode 26.6 and iOS SDK 26.5.

For an unsigned IPA without a Mac, push the project root to GitHub and run **Actions → Build unsigned Wallet IPA → Run workflow**. The workflow is `.github/workflows/build-ipa.yml`; it runs on `macos-latest`, detects the project or workspace, scheme, bundle identifier, deployment target, and product metadata, then archives with signing disabled. Manual runs include an optional `use_xcode_27_beta` input; enable it only on a runner image that actually provides Xcode 27 beta. The stable default remains the verified Xcode 26/iOS 26 SDK path.

Download the artifact named `wallet-unsigned-build-{run-number}`. It contains:

| Artifact | Purpose |
|---|---|
| `Wallet-unsigned.ipa` | Unsigned IPA with `Payload/Wallet.app` |
| `Wallet.xcarchive.zip` | Xcode archive for inspection or later user-controlled export |
| `SHA256SUMS.txt` | SHA-256 checksums for the IPA and archive |
| `build-report.txt` | Status, detected build metadata, sizes, checksums, and warnings |
| `xcodebuild-archive.log` | Raw archive-build log |

The workflow intentionally does not request or expose an Apple ID password, certificate, provisioning profile, private key, or other signing credential. The unsigned IPA is not directly installable on a normal iPhone until it has been signed.

## Signing and installation

Signing and installation are separate from the GitHub Actions build. On a trusted computer, use a legitimate Apple-ID-based sideloading tool such as [Sideloadly](https://sideloadly.io/) or use the official pairing flow for [SideStore](https://github.com/SideStore/SideStore). Enter Apple credentials only in the trusted tool’s own interface. Never upload an Apple ID password to GitHub, Manus, an unknown signing website, or an unofficial pre-signed IPA service.

A free personal Apple account commonly produces a short-lived provisioning profile, so the installed app may need periodic re-signing. Apple account, device, regional marketplace, and sideloading limits can change; consult the current official documentation for the selected method.

For the full build, checksum, report, archive, and sideloading procedure, see [`CI_SIGNING_GUIDE.md`](CI_SIGNING_GUIDE.md).

## Validation performed in this environment

The supplied accounting, INR-formatting, Light Mode, source-contract, category, import-deduplication, optional-field, no-haptics, no-quick-action, and Wallet-branding validators pass after the source updates. Additional static checks cover hold-action settings, context-menu coverage, guided intent order, and complete extension removal from the source tree and Xcode target graph. Bash syntax validation passes for the unsigned packager, and the workflow has been checked for macOS runner selection, dynamic build metadata, signing-disabled archive settings, artifact upload, checksum generation, build-report generation, cache invalidation inputs, and credential boundaries.

The macOS workflow has verified a real iOS 26 SDK compile and unsigned IPA package. The optional iOS 27 beta path was attempted, but the selected `macos-latest` runner did not have an Xcode 27 beta installation, so no iOS 27 beta compile is claimed. Use a Mac or runner image with Xcode 27 beta to complete that verification. A simulator run, accessibility audit, and signed IPA pass still require a Mac/iPhone because this Linux sandbox does not contain Xcode, Apple SDKs, simulator runtimes, or signing certificates.

## Recommended macOS QA checklist

Validate first launch and data seeding, add/edit/delete debit and credit flows, pending-income behavior, wallet transfers, recurring and fixed expense creation, JSON round-trip import/export, reset and delete-all confirmations, light/dark/system appearance, Dynamic Type at large sizes, VoiceOver labels, iPhone safe-area placement, iPad layout, keyboard dismissal, empty states, swipe actions, Siri while the app is open, and immediate refresh of balances and latest activity after an App Intent completes.
