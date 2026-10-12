# Complete the game: backlog and build order

Source: game-tester audit at `c54b046` + staff-entry-button, iPhone 18 Pro Max sim.
Owner: game director (manager). Delete this file when every item is merged.

## Finding
The 2.5D scene is not a skeleton: customers, manual cook, upgrades, location purchase and
offline earnings work. What `2677abd` deleted and nothing restored: plot interaction, coin
bubbles, warehouse bar, cook-slot UI (stock, energy), add-plot cell, staff figures, entry
points for Staff/Job sheets.

## Decisions
- **Economy (B):** pending coins auto-collect even with no cashier until a coin bubble returns;
  auto-replant never spends coins the player does not have.
- **Season:** build or delete is open; decide in H, do not leave it half-built.

## Items
| # | Item | Owner | Needs | Touches | Status |
|---|---|---|---|---|---|
| A | Staff entry button | ios-developer | - | GameRootView | merged #115 |
| B | Tier-0 economy fix | ios-developer | - | GameStore, GameCoreTests | in flight |
| J | Permission prompt after tutorial | ios-developer | - | SplashView, NotificationManager, TutorialOverlay | in flight |
| C | HUD status strip + goal routing to StaffSheet 고용 | designer -> ios-developer | A | GoalProgressBar, GameRootView, new GameUI view | spec in flight |
| D | JobSheet entry | ios-developer | C | StaffSheet or GameRootView | spec in flight |
| E | State-driven field (plots, plant/harvest, add-plot, worker figures) | art-director -> ios-developer | A, B, art | FieldLayerNode, FarmerNode, MainStallScene | art in flight |
| F | Cashier and cook figures in shop | art-director -> ios-developer | A, art | ShopNode, MainStallScene | art in flight |
| G | Farm/warehouse purchase rows in UpgradeSheet | ios-developer + designer | E | UpgradeSheet | blocked on E |
| H | Remove dead code; Season build-or-delete | ios-developer | C-G | GameStore, Systems, Tests | last |
| I | Copy review of new strings | localizer | C | String catalog | after C |

## Sequencing rules
- Same-file items serialize: GameRootView A -> C -> D; MainStallScene E -> F.
- Art runs in parallel with code that does not depend on it.
- Every PR: CI green + tester PASS; game-tester re-plays the changed flow after merge.
- No release PR until the audit reports no BLOCKER or MAJOR.

## Dead code to resolve in H
`OfflineProgressSystem` (GameStore has its own formula), `EarningsSystem.nextAffordableUpgrade`,
`GameStore.hireWorker()` no-arg, `assignWorkerToShop`, `batchCook`, `farmWorkerSection`,
`farmWorkerTier`, `TotalEarnedBadge` (unplaced), `locationTierDidChange` (no receiver).
