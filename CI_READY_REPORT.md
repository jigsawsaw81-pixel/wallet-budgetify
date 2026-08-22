# Wallet CI Readiness Report

## Result

The native Swift project is now named Wallet at the Xcode project and target level. It includes the GitHub Actions workflow at `.github/workflows/build-ipa.yml`, a reproducible unsigned IPA packager, native liquid-glass surfaces, dark-orange styling, optional transaction title/category handling, category management, deduplicating JSON import, App Intents, hold actions, and a safe signing/install guide. The Home Screen extension, App Group bridge, icon quick actions, and haptics are not included.

## Verified locally

The accounting regression suite, INR formatting, Light Mode semantic palette, source contracts, settings, editor defaults, optional transaction fields, category CRUD contracts, import deduplication, App Intent order, hold actions, no-haptics/no-quick-actions checks, and no-extension project hygiene all pass. Bash syntax validation passes for the unsigned packager, and `git diff --check` is clean.

## Verified on macOS

GitHub Actions run [32456735014](https://github.com/isshit97-wq/wallet-budgetify/actions/runs/32456735014) completed successfully on `macos-latest` with Xcode 26.6 and iOS SDK 26.5. The run produced `wallet-unsigned-build-28`, including `Wallet-unsigned.ipa`, `Wallet.xcarchive.zip`, checksums, a build report, and the raw archive log. The IPA was inspected after download and contains only `Payload/Wallet.app`, with no embedded `.appex` extension.

## Installation boundary

The IPA is unsigned and requires legitimate user-controlled Apple-ID-based signing before installation. No Apple ID, certificate, provisioning profile, private key, or other signing credential is embedded in the workflow. Never upload Apple credentials to GitHub, Manus, an unknown signing website, or an unofficial pre-signed IPA service.

## References

- [GitHub-hosted macOS runner images](https://github.com/actions/runner-images/tree/main/images/macos)
- [Apple Technical Note TN2339: Building from the Command Line with Xcode](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
