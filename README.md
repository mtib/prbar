# prbar

A macOS menu bar app for the GitHub pull requests waiting on your review.

The GitHub Slack integration stops scaling once your team is on enough repos: every review
request becomes a message, and the standing queue is invisible. `prbar` inverts that — the
queue lives in the menu bar, and you get exactly one notification per PR that newly needs you.

## What it shows

Every 60 seconds (only while the machine has a route to the internet) it runs two GitHub
searches and splits the results into three tabs, each with a live count:

| Tab | What lands there |
| --- | --- |
| **Direct** | `user-review-requested:<you>` — a review is blocked on you personally |
| **Team** | `review-requested:<you>` minus the direct set — requested from a team you're on |
| **Drafts** | anything in either set that's still a draft |

Both searches use `review:required`, so a PR drops off once it no longer blocks the merge.
PRs you authored yourself are filtered out.

The menu bar itself reads `<direct>+<team>` — drafts are deliberately left out of that total,
since they aren't waiting on you yet.

Clicking any row opens the PR in your default browser.

## Notifications

- One notification per PR, the first time it appears in **Direct** or **Team**.
- Clicking the notification opens the PR.
- **Drafts never notify.** A draft that flips to ready-for-review notifies at that point.
- The first run after install seeds silently, so you don't get your entire standing queue as
  a wall of banners.
- A PR that leaves the queue and is later re-requested notifies again.

Seen PRs are tracked in `~/Library/Application Support/prbar/notified.json`.

## Install

```sh
brew tap mtib/tap
brew install --cask mtib/tap/prbar
xattr -dr com.apple.quarantine /Applications/prbar.app
open -a /Applications/prbar.app
```

To upgrade later:

```sh
brew upgrade --cask prbar
xattr -dr com.apple.quarantine /Applications/prbar.app
```

The cask carries a real version and checksum, so Homebrew knows when a newer release exists and
`brew upgrade` does the right thing. Releasing a tag updates the cask in `mtib/homebrew-tap`
automatically (see `.github/workflows/release.yml` and `packaging/prbar.rb.tmpl`).

The `xattr` step is required: releases are ad-hoc signed rather than notarized (there's no
Apple Developer account behind this), so Gatekeeper refuses to launch the app while the
download's quarantine flag is set. Homebrew 6 dropped the `--no-quarantine` install flag; it
now only honours `HOMEBREW_CASK_OPTS=--no-quarantine`, and that doesn't help once the download
is cached, so clearing the attribute directly is the reliable route. Prefer to avoid it
entirely? [Build from source](#build-from-source) — nothing you compile locally is quarantined.

Allow notifications when macOS asks. To have it start at login, add it under System Settings →
General → Login Items.

Note `open -a prbar` may resolve to a different copy if you also have a source build around;
pass the full path when you care which one starts.

## Authentication

Two options, selectable in Settings (click the menu bar icon → **Settings…**):

- **GitHub CLI** — shells out to `gh`, reusing whatever account `gh auth login` set up.
  Requires `gh` ≥ 2.42 on your `PATH` (`/opt/homebrew/bin` and `/usr/local/bin` are probed,
  since a GUI app doesn't inherit your shell environment). Nothing to configure.
- **Access token** — calls `api.github.com` directly with a personal access token stored in
  your Keychain. Needs the `repo` and `read:org` scopes: `read:org` is what makes team review
  requests visible. No `gh` install required.

**Automatic** (the default) prefers a saved token and falls back to `gh`.

## Build from source

Requires macOS 26 and a Swift 6.3 toolchain. Xcode is *not* needed — Command Line Tools are
enough.

```sh
git clone https://github.com/mtib/prbar
cd prbar
VERSION=0.1.0 ./scripts/build-app.sh
open build/prbar.app
```

`scripts/build-app.sh` builds the SwiftPM executable, assembles `build/prbar.app` around it
with `Resources/Info.plist`, and ad-hoc signs the bundle. The signature matters: without a
bundle identity, `UNUserNotificationCenter` refuses to deliver and the Keychain item can't be
scoped to the app.

## Layout

```
Sources/PRBarCore/     queries, GitHub clients (gh + token), bucketing, notify-once planning
Sources/prbar/         MenuBarExtra app, poller, notification bridge, views
scripts/build-app.sh   SwiftPM output -> signed .app bundle
```

`PRBarCore` has no AppKit or SwiftUI dependency; the app target holds everything UI.

## Licence

MIT
