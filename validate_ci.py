from pathlib import Path

root = Path(__file__).parent
workflow = (root / ".github/workflows/build-ipa.yml").read_text(encoding="utf-8")
script = (root / "scripts/build_unsigned_ipa.sh").read_text(encoding="utf-8")
guide = (root / "CI_SIGNING_GUIDE.md").read_text(encoding="utf-8")

required_workflow = [
    "runs-on: macos-latest",
    "actions/checkout@v4",
    "actions/upload-artifact@v4",
    "scripts/build_unsigned_ipa.sh",
    "Wallet-unsigned.ipa",
    "Wallet.xcarchive.zip",
    "SHA256SUMS.txt",
    "build-report.txt",
    "hashFiles(",
]
for item in required_workflow:
    assert item in workflow, f"missing workflow requirement: {item}"

for unsafe in ["APPLE_ID", "APPLE_PASSWORD", "CERTIFICATE_BASE64", "PROVISIONING_PROFILE"]:
    assert unsafe not in workflow, f"credential material must not be embedded: {unsafe}"

for item in [
    "CODE_SIGNING_ALLOWED=NO",
    "CODE_SIGNING_REQUIRED=NO",
    "-destination 'generic/platform=iOS'",
    "archivePath",
    "Payload",
    "Wallet.app",
    "xcodebuild -list",
    "PRODUCT_BUNDLE_IDENTIFIER",
    "SHA256SUMS.txt",
    "build-report.txt",
]:
    assert item in script, f"missing build-script requirement: {item}"

assert "Sideloadly" in guide and "Do not upload the Apple ID password" in guide
print("CI validation passed: macos-latest autodetection, unsigned archive packaging, Wallet IPA artifacts, reports, checksums, caching, and credential boundaries are present.")
