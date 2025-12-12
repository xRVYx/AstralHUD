# AstralHUD (Windower 4)

AstralHUD is an all-in-one Summoner HUD focused on Blood Pacts, avatar state, ward tracking, and MP/favor economy. It renders a single draggable panel with compact sections tuned for SMN play.

## Core Features
- Blood Pact timers with bars and READY states.
- Summoner job ability cooldowns for key JAs.
- Avatar panel: HP/MP bars, TP, favor status + uptime, day/weather alignment, party-in-range for favor, damage/5s and TTK estimate.
- Ward tracker: lists tracked ward buffs, targets, and time remaining (sorted).
- Astral Flow/Conduit banners with remaining time and burst suggestions.
- MP economy: net MP/tick and time-to-OOM estimate.
- Smart guidance: highlights day/weather alignment and suggests element swaps.

## Commands
- `//astralhud` or `//ahud` — show help.
- `//astralhud toggle` — show/hide HUD.
- `//astralhud enable <module>` — enable `bptimers|pet|buffs|jobabilities`.
- `//astralhud disable <module>` — disable `bptimers|pet|buffs|jobabilities`.
- `//astralhud reset` — reset settings/position to defaults.
- `//astralhud showall on|off` — show HUD even when not on SMN.
- `//astralhud debug on|off` — verbose tracking (use for troubleshooting).
- `//astralhud listbuffs` — list tracked ward buff IDs.
- Size: `//astralhud size xsmall|small|normal|large|xlarge` — adjust font/stroke/padding.
- Background: `//astralhud bgopacity 0-255` — adjust panel background opacity.

## Tips
- Drag the panel to where you like; position and size are remembered.
- If favor range or distances feel off, toggle debug and share details so we can tune the radius.

## Feedback / Changes
This is meant to be the essential SMN HUD. Ideas, adjustments, and issues are welcome:
- Prefer different size presets? Tell us your font size, stroke, and padding.
- Want other wards tracked or element heuristics tweaked? Share your rotation.
- If something looks wrong (buff IDs, distances, timers), enable debug, note what you see, and send feedback.

Happy bursting! SMN supremacy. :)
