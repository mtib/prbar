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

The app icon is `Resources/AppIcon.svg`; `scripts/make-icon.sh` renders the committed
`Resources/AppIcon.icns` from it (rsvg-convert + iconutil). Re-run it after editing the SVG.

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
carries a quarantine flag. **The cask clears it in a `postflight_steps` block**, which is what
keeps `brew install` a single step — a deliberate trade Markus approved after a colleague hit the
"macOS doesn't trust it" wall. Don't reintroduce manual `xattr` instructions for the brew path;
they're only relevant to hand-downloaded zips.

`postflight_steps` is a declarative DSL, not Ruby run against the cask: it has no `appdir`
method, so the path is the literal template token `{{appdir}}/prbar.app` and `#{appdir}`
interpolation would raise. `run` replaces `system_command`. Verified against Homebrew 7.0.1 —
`postflight` and `url ... verified:` both deprecated there. Check a template change by rendering
it into a scratch tap (`brew tap-new mtib/scratch --no-git`, drop the file in `Casks/`, then
`brew info --cask` + `brew style --cask`); loading is what surfaces deprecations, and a cask
outside a tap will not load at all.

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
- **Do not reach for `contributionsCollection` for the reviewed-today count.** Its
  `pullRequestReviewContributions` drops everything in private repos with no error — verified
  2026-09-11, it returned 1 of ~500 reviews and set `hasAnyRestrictedContributions: true`. The
  working source is a `reviewed-by:` search with each PR's `reviews(author:)` nested in the same
  document (`ReviewActivityQuery`): 1 rate-limit point per 100-PR page, ~5 pages for a month.
- The `updated:>=` bound on that search is a superset, not the filter: submitting a review bumps
  the PR's updated stamp, so nothing inside the window hides behind it, but the results still
  carry reviews from *before* the window. `ReviewActivityQuery` drops those on `submittedAt`.
- `scripts/check-core.sh` is the one runnable check in the repo — it links PRBarCore's object
  files against a throwaway main, since there is no test target. Run it after touching
  `ReviewActivity` or `NotificationPlanner`.
- The poll loop wakes every `AppModel.tick` (5s) and only fetches once the chosen
  `PollInterval` has elapsed, rather than sleeping for the whole interval. Sleeping the full
  interval would strand a user who picked hourly and then changed their mind, and would let a
  30-minute mute run an hour. Keep the tick short and the decision inside the loop.
- Silencing notifications must never build a backlog: `NotificationPlanner` records every
  notifiable PR as seen even when the mode drops it, so un-muting announces what arrives next
  instead of replaying the quiet period. Narrow `toNotify`, never `notified`.
