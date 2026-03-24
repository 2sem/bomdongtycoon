# Monetization Plan: $1 Paid App vs AdMob

> Created: 2026-03-24

---

## Current State (AdMob)

| Component | Detail |
|---|---|
| App Open ad | Cold start, 4h interval |
| Rewarded ad | 2× offline earnings bonus |
| SDK | GoogleMobileAds (SPM) |
| Tracking | IDFA, ATT prompt required |
| app-ads.txt | Hosted at bomdongtycoon.web.app |

---

## Option A: Keep AdMob (Free + Ads)

**Pros**
- Zero friction to download (free)
- Higher install volume → more AdMob impressions → compounding revenue
- Rewarded ad creates a natural 2× mechanic players enjoy
- No upfront revenue risk

**Cons**
- Requires ATT prompt (iOS 14+) → many users deny → lower eCPM
- App Open ad interrupts cold start flow even with delay fix
- More code complexity (ad lifecycle, load timing, error handling)
- Privacy policy must cover IDFA / advertising data
- AdMob revenue for casual Korean games: est. ₩3–15/DAU/day

**Revenue estimate (rough)**
- 1,000 DAU × ₩10 avg eCPM = ₩10,000/day = ₩300,000/month

---

## Option B: $1 Paid App (₩1,200 on KR App Store)

**Pros**
- No ads, cleaner UX — better reviews and ratings
- No ATT prompt, simpler privacy policy
- Remove entire AdMob SDK → smaller binary, faster launch
- Immediate revenue per install

**Cons**
- Paywall kills 80–90% of potential installs vs free
- No recurring revenue after purchase
- Harder to grow audience organically
- Must justify value before download

**Revenue estimate (rough)**
- 100 paid installs × ₩840 (after 30% cut) = ₩84,000 total

---

## Recommendation

| Signal | Favors |
|---|---|
| Game is short-session idle → high retention not guaranteed | AdMob |
| Korean market prefers free → lower install friction matters | AdMob |
| No IAP system yet | AdMob |
| Small brand, first release | AdMob |
| User satisfaction / review quality priority | Paid |

**Verdict: Stay AdMob for 1.0.0.** Revisit paid or freemium IAP after gathering retention data (target: D7 > 20%).

---

## If Switching to Paid — Work Required

```
feat/remove-admob
```

### Code Changes
- [ ] Remove `GoogleMobileAds` from `Tuist/Package.swift`
- [ ] Remove `.external(name: "GoogleMobileAds")` from `Project.swift`
- [ ] Delete `SwiftUIAdManager.swift`
- [ ] Remove `adManager` from `BomDongTycoonApp`
- [ ] Remove `GADMobileAds.sharedInstance().start()` from `SplashView` — simplify to just `isDone = true` after delay
- [ ] Remove rewarded ad button from offline earnings popup (`GameRootView`)
- [ ] Remove `GADApplicationIdentifier` from `Project.swift` infoPlist
- [ ] Remove `SKAdNetworkItems` (no longer needed without AdMob)
- [ ] Keep `FirebaseMessaging` (FCM for push is still useful)

### Hosting / ASO
- [ ] Remove `hosting/app-ads.txt` (no longer required)
- [ ] Update privacy policy — remove AdMob / IDFA section
- [ ] Update App Store description — remove "광고 시청 시 2배" copy
- [ ] Set price to ₩1,200 (tier 1) in App Store Connect

### Estimated effort: 1 session

---

## Future Option C: Freemium IAP

Remove ads via one-time IAP (₩2,500 "광고 제거") instead of upfront paywall.

Requires:
- StoreKit 2 integration
- `AdFreeManager` to gate ad display
- App Store IAP configuration

**Defer to 1.1.0** after validating retention.
