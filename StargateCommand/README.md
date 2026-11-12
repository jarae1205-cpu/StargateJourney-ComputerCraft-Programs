# Stargate Command

Two monitor programs and a shared library for ComputerCraft stargates:

- **Gate Room**: an SGC style gate room screen. The gate is drawn in the look of its series, the chevrons lock one by one, the inner ring turns, the wormhole forms with a kawoosh and the iris closes over it.
- **Gate Network Hub**: a touch screen of destination cards. Each card has its own portal colour and a tab (Milky Way, Pegasus, Crossover...). Tap a card to dial it.

Both work with **Stargate Journey** (Minecraft 1.20.1, CC: Tweaked) and with **SGCraft**: Greg Ewing's original (Minecraft 1.7.10 to 1.10.2) and the 1.12.2 SGCraft 2.x line (written against 2.3). They share one address book with the [Personal Dialer](../PersonalDialer/).

![Gate Room](../imgs/GateRoom.png)

*Gate Room on a 4x3 monitor. Top: dialing Abydos on an SG-1 gate, and the open wormhole. Bottom: the iris closed over an incoming wormhole, and an SGCraft gate with a 9-symbol address. These screens were rendered from a headless CC: Tweaked test harness with simulated gates, not captured in-game.*

## Gate looks

The look is picked from the gate type and its Stargate Journey variant. You can also cycle it with the **STYLE** button.

![Gate styles](../imgs/GateStyles.png)

| Style | Used for |
|---|---|
| Milky Way | Stargate Journey Milky Way gates |
| SG-1 | the `milky_way_sg-1` and `milky_way_promo` variants |
| Movie | the `milky_way_movie` variant: sand coloured stone, big amber chevrons |
| Pegasus | Stargate Journey Pegasus gates: slate ring, the dialed symbols light up |
| Atlantis | the `pegasus_atlantis` variant, and any variant with "lantea" in its name |
| Universe | Universe gates: dark ring, white chevron lights |
| Tollan | Tollan gates: slim white ring |
| Classic | Classic gates: bronze ring |
| Infinity | variants with "infinity" in their name: pale horizon with spiral lines, like the animated series |
| Legacy Hybrid | variants with "hybrid" or "legacy" in their name: amber, red and purple chevrons with a blue master chevron |
| SGCraft | gates from Greg's SGCraft |

Variants from resource packs are matched by name, so a variant called `lantea_gate` gets the Atlantis look.

## Requirements

- **Stargate Journey**: a basic, crystal or advanced crystal interface next to the computer or on a wired modem network. Pegasus, Universe, Tollan and Classic gates need a crystal interface to dial. The local address and the caller's address need an advanced crystal interface.
- **SGCraft**: the ComputerCraft stargate interface under the gate base.
- An advanced computer and an advanced monitor. The programs also run on the computer's own screen.
- Optional: a speaker (alarm for incoming wormholes) and redstone alarm lights.

Mods without a ComputerCraft interface can't be driven by these programs.

## Installation

With HTTP enabled in the CC: Tweaked config:

```
wget run https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/StargateCommand/install.lua
```

This downloads `gateroom.lua`, `hub.lua`, `dialer.lua` and the `sgc` folder into the current folder. Run it again to update; your address book is kept.

To start one of them when the computer boots, add its name:

```
wget run https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/StargateCommand/install.lua gateroom
```

Without HTTP, copy `gateroom.lua`, `hub.lua` and the whole `sgc` folder to the computer. The programs need `sgc` next to them.

## Gate Room

```
gateroom              first advanced monitor (or the computer screen if there is none)
gateroom monitor_3    a specific monitor
gateroom term         the computer screen
```

A 4x3 or 5x3 advanced monitor gives the best picture. 3x2 works with a compact panel.

| Touch | Computer | Action |
|---|---|---|
| `DIAL` | Ctrl+D | pick a destination from the address book |
| | type an address, Enter | dial it (`26 6 14 31 11 29` or `WLDQ-DQB-MT`) |
| `CLOSE` / `ABORT` | Ctrl+X | close the wormhole or stop dialing |
| `IRIS` or the gate | Ctrl+I | open or close the iris |
| `STYLE` | Ctrl+S | next gate look (Auto, then every style) |
| | Ctrl+Q | quit |

The dialing computer panel shows each chevron as it is encoded and locked, the destination or caller, how long the wormhole has been open, the gate's energy and the iris. Gates dialed from a DHD show up the same way.

An incoming wormhole flashes the screen red ("OFFWORLD ACTIVATION"), sounds an alarm on an attached speaker and can power a redstone line for alarm lights.

Settings at the top of `gateroom.lua`:

- `interfaceName`: which gate interface to use if the computer reaches several
- `textScale`, `frameTime`: monitor detail and animation speed (raise `frameTime` on a busy server)
- `fastDial`: engage symbols directly instead of turning the Milky Way ring
- `autoIris`: close the iris when another gate dials in. Off by default, because your own team coming home hits the iris too
- `alarmSide`: redstone side powered while an incoming wormhole forms, e.g. `"back"`
- `klaxon`: speaker alarm on or off
- `autoClose`: close an outgoing wormhole this many seconds after someone steps through (0 = never)

## Gate Network Hub

```
hub              first advanced monitor (or the computer screen)
hub monitor_3    a specific monitor
hub term         the computer screen
hub chart        add the planned destinations from the crossover network chart
```

![Network Hub](../imgs/NetworkHub.png)

*Left: dialing Chulak from the hub. Right: giving a planned destination an address.*

- **Tap a card** to select it, tap it again (or `DIAL`) to dial.
- **Tabs** along the top filter by group. The tab is remembered.
- **`+ ADD`** adds a destination. **`EDIT`**, then a card, edits or deletes one. Type on the computer; Tab moves to the next field; tap a colour swatch to pick the portal colour.
- **Planned destinations** have a name but no address yet. They show a dark gate until you add the address. `hub chart` adds the gates and worlds from the crossover network chart (SGC, Home Base, the Atlantis Gate, the Republic Gate, the Aperture Gate...) as planned cards, so you can fill in the addresses as you build those worlds.
- `CLOSE` closes the wormhole, `IRIS` opens or closes the iris.

A 4x3 monitor shows 12 cards per page, a 3x2 monitor 6. Smaller screens use compact cards.

## Shared address book

The Gate Room, the Hub and the Personal Dialer all read `/dialer_addresses.db`. On an advanced computer you can run the Gate Room on the monitor and the dialer in a second tab (`bg dialer`). Each entry has:

- `name`, `note`
- `address`: a list of numbers for Stargate Journey, a string of 7 or 9 letters/digits for SGCraft, or nothing for a planned destination
- `group` and `color` (used by the Hub)

## The sgc library

`sgc/` can be used by your own programs:

| Module | What it does |
|---|---|
| `sgc.gate` | finds the gate interface (Stargate Journey or SGCraft), reads its state, turns events into simple messages, dials (Milky Way ring rotation or direct engaging), iris |
| `sgc.address` | parses, formats and compares both address formats |
| `sgc.book` | the shared address book |
| `sgc.styles` | the gate looks and their palettes |
| `sgc.pixels` | a pixel canvas drawn with teletext characters (2x3 pixels per character) |
| `sgc.ring` | draws a gate on a canvas: ring, chevrons, symbols, event horizon, kawoosh, iris |
| `sgc.ui` | buttons and touch areas |

```lua
local gate = require("sgc.gate").find()
print(gate.typeName, gate.state)
local ok, why = gate:dial({ 26, 6, 14, 31, 11, 29 })
```

## SGCraft 2.3 notes

- The computer interface doesn't report whether a gate is Milky Way, Pegasus, Universe or an Ori supergate, so every SGCraft gate starts with the SGCraft look. Tap **STYLE** in the Gate Room (or pick a theme in the dialer's gate info) to match a Pegasus or Universe gate. The choice is remembered.
- ZPMs feeding the gate are shown next to its energy.
- Incoming wormholes are recognised from the gate's dialing direction, which 2.3 reports instead of the old `sgDialIn`/`sgDialOut` events.
- Dialing errors are shown as text ("No stargate at that address", "Not enough energy to dial"...) instead of SGCraft's message keys.

## Notes

- Dialing reads the gate state from events and also polls it, so a missed event does not leave the screen stuck.
- On an SGCraft gate the inner ring animation is drawn by the program; SGCraft does not report the ring position.
- The Gate Room changes the colour palette of its monitor and restores it when it quits.
- Not tested in a live game yet. The programs were run against simulated Stargate Journey, SGCraft (original) and SGCraft 2.3 interfaces built from each mod's source code.
