# Hush

*The internet. Without the noise.*

A Safari ad blocker for iPhone and iPad. It blocks ads, trackers, cookie prompts
and other annoyances, and skips YouTube video ads.

## How it works

```
filter lists (AdGuard, Peter Lowe, ...)        Adblock syntax, downloaded by the app
        │  ProtectionEngine.download
        ▼
App Group: filters/<id>.txt
        │  SafariConverterLib (AdGuard, GPL-3.0)
        ▼
App Group: blockers/<category>.json            Safari content blocker JSON
        │  SFContentBlockerManager.reloadContentBlocker
        ▼
5 content blocker extensions ──► Safari/WebKit blocks requests and hides elements
```

| Feature | Mechanism |
|---|---|
| Block ads | `AdsBlocker`: AdGuard Base + Mobile Ads. Network rules block ad requests; `css-display-none` rules hide leftover slots. |
| Preserve privacy | `PrivacyBlocker`: AdGuard Tracking Protection + Peter Lowe (EasyPrivacy-style tracker blocking). Optional phishing list. |
| Eliminate annoyances | `AnnoyancesBlocker`: AdGuard Cookie Notices, Pop-ups, App Banners, Other Annoyances (Widgets and Social optional). |
| Regional ads | `RegionalBlocker`: AdGuard language lists; the device language's list is on by default. |
| Custom rules / allowlist | `CustomBlocker` holds user rules; allowlisted domains get an `ignore-previous-rules` exception in **every** blocker. |
| YouTube ads | `YouTubeExtension`, a Safari web extension: hides ad slots, mutes, fast-forwards and skips video ads, and removes the anti-adblock dialog. |
| Faster pages, less data and battery | A side effect: blocked resources are never downloaded or executed. There is no separate code for this. |

The lists are spread across several extensions because Safari limits each
content blocker to 150,000 rules. Since iOS 17 each blocker's JSON also has to
stay under a size limit (19 MB on 17.2+, 10 MB on 17.0–17.1), or Safari's
extension process crashes. `ProtectionEngine.recommendedMaxJsonSizeBytes`
applies these limits. With the default lists, sizes are: Ads 42.7k rules /
13 MB, Privacy 109k / 11.8 MB, Annoyances 13.9k / 3 MB.

Lists refresh on first launch, when they are more than 3 days old, on
pull-to-refresh, and through a `BGAppRefreshTask` roughly every 12 hours.

## Project layout

```
project.yml                  XcodeGen spec (source of truth for Hush.xcodeproj)
App/                         SwiftUI app
Extensions/ContentBlocker/   One handler shared by all 5 content blocker targets
Extensions/YouTube/          Safari web extension (content.js does the work)
Packages/BlockerKit/
  BlockerShared              Categories + App Group file layout (linked by extensions)
  BlockerKit                 Filter catalog, settings, download + compile engine
```

## Build and run

1. Open `Hush.xcodeproj` in Xcode 15 or later.
2. In **Build Settings** of the project (not a target), set:
   - `APP_BUNDLE_ID`: a reverse-DNS ID you own, e.g. `com.yourname.hush`
   - `DEVELOPMENT_TEAM`: your team ID

   Or edit both in `project.yml` and run `xcodegen generate`.
   All extension IDs and the App Group (`group.$(APP_BUNDLE_ID)`) are derived
   from those two values; automatic signing registers them.
3. Run the `Hush` scheme on a device or simulator. On the first build,
   Xcode asks you to trust SafariConverterLib's `GenerateVersion` build
   plugin; choose **Trust & Enable**. (On the command line, pass
   `-skipPackagePluginValidation` to `xcodebuild`.)
4. On the device, open Settings › Apps › Safari › Extensions (iOS 17 and
   earlier: Settings › Safari › Extensions). Turn on the five
   "Hush …" blockers and "Hush for YouTube", and allow the YouTube
   extension on youtube.com.

## Tests

`Packages/BlockerKit/Tests` covers domain normalisation, default list
selection, rule conversion, allowlist ordering and the empty-list fallback.
The live test downloads the real default lists and checks each blocker fits
Safari's limits:

```
cd Packages/BlockerKit
swift test                                               # offline tests
HUSH_LIVE_TESTS=1 swift test --filter LiveFilterTests
```

`swift test` needs full Xcode; Command Line Tools alone lack the Swift
Testing macro plugin.

## Limitations

- Safari content blockers cannot run AdGuard scriptlets, `$removeparam` or
  extended CSS. The converter skips those rules (reported as "errors" in the
  stats). Supporting them needs a web extension running AdGuard's
  `@adguard/safari-extension` JS on every site.
- iOS has no API to count blocked requests, so the app shows rule counts
  rather than "ads blocked" statistics.
- YouTube changes its page markup often; `content.js` selectors need upkeep.

## License

Copyright © 2026 Lumo.

Hush is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version. It is distributed WITHOUT ANY WARRANTY; see [`LICENSE`](LICENSE).

The app shows this notice, a link to the source and every credit under
Home › About & licenses (`App/Views/AboutView.swift`), as GPLv3 section 5(d)
requires. `LICENSE` and `THIRD_PARTY_NOTICES.md` are bundled into the app for
that screen.

Third-party components, with full license texts in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md):

| Component | License |
|---|---|
| [SafariConverterLib](https://github.com/AdguardTeam/SafariConverterLib) (AdGuard) | GPL-3.0 |
| [PunycodeSwift](https://github.com/gumob/PunycodeSwift) (Gumob) | MIT |
| [swift-psl](https://github.com/ameshkov/swift-psl) (Andrey Meshkov) | MIT |
| [Public Suffix List](https://publicsuffix.org) data (Mozilla), inside swift-psl | MPL-2.0 |
| [Fluent Emoji](https://github.com/microsoft/fluentui-emoji) (Microsoft) | MIT |

When adding a dependency or asset, add it to `THIRD_PARTY_NOTICES.md` and to
the `credits` list in `AboutView.swift`, and check its license is compatible
with GPLv3 (MIT, BSD, Apache-2.0, MPL-2.0 and LGPL are; most "non-commercial"
licenses are not).

Filter lists (AdGuard filters: GPL-3.0; EasyList family: GPL-3.0 / CC BY-SA
3.0; Peter Lowe's list: see pgl.yoyo.org) are not part of the app. They are
downloaded from their publishers at runtime and keep their own licenses.

## Before production publish

- [ ] **Publish the source.** GPLv3 requires the source of every released
  build to be available. Push this project to the URL in
  `AboutView.sourceURL` (currently `https://github.com/lumohq/hush`) and
  tag each App Store release (for example `v1.0`), so the published source
  always matches what users install. Commit `Package.resolved`.
- [ ] **Know the App Store / GPL risk.** Apple's App Store terms add usage
  rules that many read as conflicting with GPLv3. As the copyright holder
  you can permit App Store distribution of your own code, but not of
  AdGuard's SafariConverterLib; if AdGuard objected, Apple could remove the
  app. Moving the conversion to a server (shipping only the generated JSON)
  removes this risk.

- [ ] **Change the bundle ID.** It is still `com.talhaarshad.adshield`, kept from
  the app's earlier name. Users never see it, but a free Apple account can
  register only 10 App IDs per week, and the first signing already used 7 (the
  app plus 6 extensions), so changing it would have blocked signing. Once on
  the paid Apple Developer Program, set `APP_BUNDLE_ID` in `project.yml` (for
  example `com.talhaarshad.hush`) and run `xcodegen generate`. The extension
  IDs and the App Group follow automatically.
- [ ] **Confirm the app name is available.** Several App Store apps already use
  "Hush", including *Hush Nag Blocker*, a Safari cookie-banner blocker in the
  same category. App Store Connect requires a unique app name, and a name this
  close to a competitor's risks review and trademark problems. Reserve the
  name in App Store Connect early, or pick a variant.
- [ ] **Shorten the tagline for the App Store subtitle.** "The internet.
  Without the noise." is 32 characters; App Store Connect allows 30 for the
  subtitle. It can stay as-is in the app, description and screenshots.
  Options that fit: "Internet without the noise" (26) or
  "The web, without the noise." (27).

## Future scope

- **Adult site blocker.** A sixth content blocker (`BlockerCategory.adult`,
  extension `$(APP_BUNDLE_ID).blocker.adult`) fed by a public adult-domain
  list, off by default. Needs a new category case, a catalog entry, a target
  in `project.yml`, and a row on the home screen. Domain lists of this kind are
  large, so check the compiled size against Safari's 150k rule / 19 MB limits
  before choosing a list.
- **Block ads in every app (Chrome and other browsers).** Safari extensions
  don't run in Chrome or other apps, so this needs a phone-wide DNS filter: an
  on-device "local VPN" (`NEPacketTunnelProvider`) that answers ad and tracker
  domains with "not found" for every app. Keep it on-device so Hush still never
  sees anyone's browsing; an encrypted-DNS profile would need a Hush-run DNS
  server that sees every lookup. Domain blocking only: no cookie banners,
  hidden ad boxes or YouTube skipping outside Safari. Uses the VPN slot, so it
  conflicts with a real VPN, and the extension must fit iOS's ~50 MB memory
  limit. Needs the paid Developer Program (Network Extension capability).
- **Block ads in games.** Builds on the phone-wide filter above by adding
  ad-network SDK domains (AdMob, Unity Ads, AppLovin, ironSource and similar).
  Optional and off by default: rewarded ads ("watch an ad for coins") stop
  working, and some games misbehave when their ad SDK can't connect. iOS
  doesn't say which app made a DNS request, so it applies to all apps, not
  just games.
