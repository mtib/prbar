# prbar

macOS menu bar app showing GitHub PRs awaiting review. See README.md for behaviour.

## Build

There is no Xcode on the dev machine — only Command Line Tools. Consequences:

- `xcodebuild` is unavailable; everything goes through SwiftPM.
- **`swift test` cannot run locally**: neither `XCTest.framework` nor the `Testing` module
  ships with Command Line Tools (only `libTestingMacros.dylib` does). There is no test target
  for that reason. If tests are ever added, they only run in CI.
- `scripts/build-app.sh` is the only build entry point that produces a runnable app. `swift
  build` alone gives a bare executable, which is **not** enough:
  `UNUserNotificationCenter.current()` traps without a bundle identifier, so the app must run
  from the assembled, ad-hoc-signed `.app`.

```sh
VERSION=0.1.0 ./scripts/build-app.sh && open build/prbar.app
```

## Release

Push a `v*` tag. `.github/workflows/release.yml` builds on `macos-26`, packages with `ditto`
(not `zip` — it preserves bundle metadata), and publishes `prbar.zip`.

The `update-tap` job then rewrites `Casks/prbar.rb` in `mtib/homebrew-tap` from
`packaging/prbar.rb.tmpl`, substituting the version and the packaged zip's sha256. **Edit the
template, never the tap copy** — the next release overwrites it. It needs the `TAP_TOKEN`
secret on this repo (a PAT with write access to the tap), mirroring how `mtib/dhl` does it;
`github.token` cannot push cross-repo.

The cask carries a real `version` + `sha256` (not `version :latest`), which is what lets
`brew upgrade --cask prbar` and `brew livecheck` detect new releases. The `livecheck` block uses
`strategy :github_latest`.

Releases are ad-hoc signed, not notarized, so a downloaded copy is Gatekeeper-rejected while it
carries a quarantine flag. **The cask clears it in a `postflight` block**, which is what keeps
`brew install` a single step — a deliberate trade Markus approved after a colleague hit the
"macOS doesn't trust it" wall. Don't reintroduce manual `xattr` instructions for the brew path;
they're only relevant to hand-downloaded zips.

Homebrew 6 removed the `--no-quarantine` **install flag** (it only survives via
`HOMEBREW_CASK_OPTS`, and that has no effect once the download is cached), so don't document
that flag — verified 2026-07-27 against Homebrew 6.0.12.

The real fix is notarization, which needs an Apple Developer Program membership ($99/yr); this
machine has **no** codesigning identity (`security find-identity -v -p codesigning` → 0 valid),
so it isn't currently possible.

Beware that `open -a prbar` resolves through LaunchServices and may start a source build in
`~/Code/prbar/build` instead of `/Applications`. Use full paths when verifying.

## Runner requirement

CI must stay on `macos-26`: `Package.swift` sets a macOS 26 deployment target, which cannot be
built against an older SDK.

## Gotchas

- The poller is started from a `.task` on the **status item label**, not the panel view. The
  panel is created lazily on first click, so starting it there would delay all polling and
  notifications until the user opened the menu.
- `gh` is located by probing `/opt/homebrew/bin` etc. A GUI-launched app inherits no shell
  `PATH`, so `which gh` is not an option.
- Both searches keep drafts in the result set (no `draft:false`) and bucket them client-side,
  which is what makes the draft tab free. Drafts must never notify.
