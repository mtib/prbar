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

The Homebrew cask at `mtib/homebrew-tap` `Casks/prbar.rb` points at
`releases/latest/download/prbar.zip` with `version :latest` / `sha256 :no_check`, so **the tap
needs no update per release**. `brew style` flags that zip URL (`Cask/Url` wants tarballs);
that cop is wrong for `.app` release assets and Homebrew forbids inline rubocop directives, so
the single warning is expected.

Releases are ad-hoc signed, not notarized, so a brew-installed copy is Gatekeeper-rejected
until `xattr -dr com.apple.quarantine /Applications/prbar.app` is run. Homebrew 6 removed the
`--no-quarantine` **install flag** (it only survives via `HOMEBREW_CASK_OPTS`, and that has no
effect once the download is cached), so don't document that flag — verified 2026-07-27 against
Homebrew 6.0.12.

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
