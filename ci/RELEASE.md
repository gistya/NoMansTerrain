# Releasing the installers (macOS + Windows)

The [`Release Installers`](../.github/workflows/release-installer.yml) workflow builds both
downloadable installers and publishes them on a GitHub Release:

- **macOS** — signs `NoMansTerrain.app` with your **Developer ID** + hardened runtime, wraps it in a
  signed **`.pkg`**, **notarizes** it with Apple and staples the ticket. Opens with no Gatekeeper
  warning.
- **Windows** — reuses [`windows-crossui.yml`](../.github/workflows/windows-crossui.yml) to build the
  pure-Swift SwiftCrossUI app and package `NoMansTerrainSetup.exe` (+ `NoMansTerrain.msi`).

## How to cut a release

**Tag a version** — both installers are built and attached to the tag's GitHub Release:

```sh
git tag v1.1.0
git push origin v1.1.0
```

**Or run on demand** — Actions → *Release Installers* → *Run workflow*. Both installers are uploaded
as build artifacts (no Release is created/attached).

## One-time setup

### macOS signing & notarization secrets

You need two **Developer ID** certificates from
<https://developer.apple.com/account/resources/certificates>:

- **Developer ID Application** — signs the `.app`.
- **Developer ID Installer** — signs the `.pkg`.

In **Keychain Access** select **both** certificates (each with its private key) → right-click →
**Export 2 items…** → save one `certificates.p12` with a password, then base64-encode it:
`base64 -i certificates.p12 | pbcopy`.

For notarization, at <https://appstoreconnect.apple.com/access/integrations/api> create a **Team Key**
and download `AuthKey_XXXX.p8` once; note the **Key ID** and **Issuer ID**.

Add these repository secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `CERTIFICATES_P12` | Base64 of the combined `.p12` (the `pbcopy` output). |
| `CERTIFICATES_P12_PASSWORD` | The password set when exporting the `.p12`. |
| `KEYCHAIN_PASSWORD` | Any random string — used for the throwaway CI keychain. |
| `APP_STORE_CONNECT_KEY_ID` | The Key ID. |
| `APP_STORE_CONNECT_ISSUER_ID` | The Issuer ID. |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Full contents of `AuthKey_XXXX.p8`, including the `-----BEGIN/END PRIVATE KEY-----` lines. |

The team ID (`Y453UXCT86`) is baked into the workflow and `ci/ExportOptions.plist` — no secret needed.

### Shared secret (both platforms)

| Secret | Value |
| --- | --- |
| `HASTINGS_TOKEN` | Fine-grained PAT with **Contents: Read-only** on `gistya/hastings` (a private `../hastings` path dependency of `NoMansTerrainCore`). Cloned as a sibling of the repo on both runners. |

## Notes

- **Xcode 26.** The macOS job runs on `macos-26` (the app uses Swift 6.2 default-actor isolation). If
  GitHub's hosted images lack Xcode 26, point `runs-on` at a self-hosted macOS runner that has it.
- **Entitlements.** The app is signed for Developer ID with hardened runtime and **no custom
  entitlements** — the checked-in `NoMansTerrain.entitlements` (push / iCloud) isn't wired into the
  target and those capabilities need provisioning profiles Developer ID distribution doesn't carry.
- **Windows build** is heavy (~45 min+). It's reused by the release workflow via `workflow_call`, so a
  tag build produces both installers in one run and attaches them to the same Release.
