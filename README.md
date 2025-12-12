# AstralHUD (Windower 4)

AstralHUD is an all-in-one Summoner HUD focused on Blood Pacts, avatar state, ward tracking, and MP/favor economy. It renders a single draggable panel with compact sections tuned for SMN play.

## Core Features
- Blood Pact timers with bars and READY states.
- Pact queue overlay: set your next Rage/Ward with overwrite warning if you would clip a long ward.
- Avatar panel: HP/MP bars, TP, favor status + uptime, day/weather alignment, party-in-range for favor, damage/5s and TTK estimate.
- Ward tracker: lists tracked ward buffs, targets, and time remaining (sorted).
- Astral Flow/Conduit banners with remaining time and burst suggestions.
- MP economy: net MP/tick and time-to-OOM estimate.
- Smart guidance: highlights day/weather alignment and suggests element swaps.

## Commands
- `//astralhud` or `//ahud` — show help.
- `//astralhud toggle` — show/hide HUD.
- `//astralhud enable <module>` — enable `bptimers|pet|buffs`.
- `//astralhud disable <module>` — disable `bptimers|pet|buffs`.
- `//astralhud reset` — reset settings/position to defaults.
- `//astralhud showall on|off` — show HUD even when not on SMN.
- `//astralhud debug on|off` — verbose tracking (use for troubleshooting).
- `//astralhud listbuffs` — list tracked ward buff IDs.
- Pact queue: `//astralhud setrage <name>`, `//astralhud setward <name>`, `//astralhud clearqueue`.
- Size: `//astralhud size xsmall|small|normal|large|xlarge` — adjust font/stroke/padding.

## Tips
- Drag the panel to where you like; position and size are remembered.
- Set your planned Rage/Ward so teammates can anticipate your next move (and to see overwrite warnings).
- If favor range or distances feel off, toggle debug and share details so we can tune the radius.
- Ward overwrite warning triggers when Ward is ready and a ward buff has >30s left; ask if you want a different threshold.

## Feedback / Changes
This is meant to be the essential SMN HUD. Ideas, adjustments, and issues are welcome:
- Prefer different size presets? Tell us your font size, stroke, and padding.
- Want other wards tracked or element heuristics tweaked? Share your rotation.
- If something looks wrong (buff IDs, distances, timers), enable debug, note what you see, and send feedback.
