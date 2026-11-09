# Adopt Me Universal Hub

Client-side Luau hub for Roblox Adopt Me. Based on inspection of the supplied November 2026 decompiled client scripts. **Game-server validation still applies. The code has not yet been live-tested in Roblox.**

## Run the hub

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/zvzt/Adopt-Me/main/hub.lua"))()
```

## Hub features

- **Dashboard:** bucks, location, selected pet, active ailments, attempts, lure counters, quick farm start/stop
- **Needs farm:** priority scheduling, pet-me request, walking movement, school/salon/hospital/camping/park travel, nearby furniture interactions
- **Food:** existing food/drink support, explicitly opt-in because food is consumed
- **Pet manager:** select an owned pet, equip it, one-click petting and feeding, auto-requip in farm mode
- **Lures:** auto-claim eligible lures; bait placement opt-in and only from owned bait (no automatic purchases)
- **Money trees:** attempts nearby money tree interactions when present (no remote reward bypass)
- **Owned rewards:** optional auto-opening of owned gifts, auto-mailbox claims, one-click login handout claims
- **Idle pet pen:** assign and remove a selected pet through the game’s idle-progression controls
- **Travel:** commonly used interiors, home, saved position
- **Utilities:** anti-AFK, anti-void, noclip, infinite jump, speed/jump settings, ESP, low graphics, rejoin
- **Diagnostics:** logs, copy/save logs, settings persistence (when executor file APIs are supported)
- **Event:** original Lightning Dimension autofarm launcher and stop button

All farm switches start disabled unless changed in saved settings. Press **START FULL FARM MODE** to enable the needs + lure claim workers. Auto-bait, auto-feed, auto-money-tree, auto-gift-opening and auto-mailbox remain off until separately enabled. Gift opening and bait/food use consume owned inventory items. Use **Right Shift** or the on-screen button to hide/show the window.

## Original Lightning Dimension autofarm

The existing event-focused script remains **unchanged** in `main.lua`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/zvzt/Adopt-Me/main/main.lua"))()
```

Its original features are lightning bottle farming, trade/refill, storm-chip cookie bait, pet-pen lures, and event travel. The universal hub's **Events** tab can launch and stop it separately.

## Compatibility and limitations

- Requires a client/executor that permits reading the game's `Fsys` modules; unsupported executors leave the hub's local utilities accessible but may block automation.
- Some needs require valid inventory, equip state, owned furniture, or visiting the correct region, and actions may require multiple checks to complete.
- Ailment, lure and shop server rules may change with updates. All farm attempt counters are **requests**, not proof of rewards or completion.
- No guaranteed Bucks, instant hatching, trade duplication, or Robux bypass.
- This hub is untested in a live client. Check the **Logs** tab after the first run and report failing tasks.

## Stop and cleanup

Close the hub using the `×` button or execute:

```lua
getgenv().AdoptMeUniversalHubStop()
```

The stop function disconnects listeners and attempts to restore local lighting, collisions, and movement defaults.

## Files

- `hub.lua` — new universal hub
- `main.lua` — original Lightning Dimension event autofarm

For executor-specific issues, contact @zxt.lol.
