# Wallet: no-Mac build and sideload path

The repository now contains a GitHub Actions workflow at `.github/workflows/build-ipa.yml`. It runs on `macos-latest`, detects the supplied Xcode project or workspace, discovers the scheme and build metadata, archives with signing disabled, packages `Payload/Wallet.app`, and uploads the unsigned IPA together with the archive, checksum file, build report, and archive log.

## Build through GitHub Actions

Create a GitHub repository and push the project root, including `.github/workflows/build-ipa.yml` and `scripts/build_unsigned_ipa.sh`. A public repository avoids the private-repository macOS Actions multiplier, but a private repository is also supported within its available Actions quota. Open **Actions → Build unsigned Wallet IPA → Run workflow** or push to `main`/`master`.

After a successful run, download the artifact named `wallet-unsigned-build-{run-number}`. It contains `Wallet-unsigned.ipa`, `Wallet.xcarchive.zip`, `SHA256SUMS.txt`, `build-report.txt`, and `xcodebuild-archive.log`. The report records the status, detected project or workspace, scheme, bundle identifier, product name, deployment target, Xcode version, SDK version, artifact sizes, checksums, and the unsigned-build warning.

The workflow intentionally does not contain an Apple ID, certificate, provisioning profile, private key, or signing secret. Do not put those credentials into the repository or GitHub Actions for this unsigned build. The generated IPA is an unsigned app container, not an installable signed package.

The archive also contains the `BudgetifyWidget` iOS 17 extension. It reads the app’s persisted balance snapshot through the App Group `group.com.budgetify.native`, which is declared in both targets’ entitlements. A signed build must be provisioned with that App Group capability before the widget can be installed on a device.

## Check the generated files

On macOS or Linux, verify the downloaded artifacts with:

```sh
shasum -a 256 Wallet-unsigned.ipa Wallet.xcarchive.zip
cat SHA256SUMS.txt
```

The checksum values printed locally should match the lines in `SHA256SUMS.txt`. The archive is useful for later inspection or a separate user-controlled signed export; it is not itself a signed installation.

## Sign and install with a legitimate sideloading tool

Signing and installation are separate from the GitHub Actions build. On a trusted computer, open a legitimate Apple-ID-based tool such as [Sideloadly](https://sideloadly.io/), select `Wallet-unsigned.ipa`, connect the iPhone, and enter Apple credentials only in that trusted tool’s own interface. Do not upload the Apple ID password to GitHub, Manus, an unknown signing website, or a third-party “pre-signed IPA” service.

A free personal Apple account commonly produces a short-lived provisioning profile, so the installed app may need periodic re-signing. [SideStore](https://github.com/SideStore/SideStore) can provide wireless refreshing after its official pairing setup, subject to Apple’s account and device limits. Users in eligible EU regions may have additional official alternative-marketplace options. Check the current official documentation for any installation method before trusting it.

GitHub Actions compiles the Swift project and produces the unsigned artifact. It cannot safely sign with a user’s Apple ID without the user-controlled signing identity and provisioning profile, so this workflow intentionally stops at the unsigned IPA. Physical-device haptic behavior and widget installation must be verified on a signed iPhone build; they are not claimed as verified in this Linux environment.

## References

- [GitHub-hosted macOS runner images](https://github.com/actions/runner-images/tree/main/images/macos)
- [Apple Technical Note TN2339: Building from the Command Line with Xcode](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
- [SideStore official project](https://github.com/SideStore/SideStore)
