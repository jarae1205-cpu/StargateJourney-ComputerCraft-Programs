# Stargate Command

Two monitor programs and a shared library for ComputerCraft stargates:

- **Gate Room**: an SGC style gate room screen. The gate is drawn in the look of its series, the chevrons lock one by one, the inner ring turns, the wormhole forms with a kawoosh and the iris closes over it.
- **Gate Network Hub**: a touch screen of destination cards. Each card has its own portal colour and a tab (Milky Way, Pegasus, Crossover...). Tap a card to dial it.

They share one address book with the [Personal Dialer](../PersonalDialer/) and work with these mods:

| Mod | Minecraft | What the computer needs | Dials |
|---|---|---|---|
| **Stargate Journey** | 1.20.1 | a basic, crystal or advanced crystal interface | every gate type |
| **SGCraft** (Greg Ewing's, and SGCraft 2.x, the "Stargate Network" mod) | 1.7.10 to 1.12.2 | the ComputerCraft stargate interface | every gate |
| **Lantea: Stargates** 0.7.7.0+ | 1.20.1 (Forge), 1.21.1 (NeoForge) | a Stargate Power Coupler Kit on the gate controller | Milky Way gates (Pegasus gates can be watched, not dialed) |
| **Just Stargate Mod** (JSG) | 1.20.1 | the gate's base block (it is a CC: Tweaked peripheral) | every gate |

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
| Continuum | variants with "continuum" or "arctic" in their name: the gate found frozen in the Arctic in Stargate: Continuum, frosted blue-grey stone flecked with ice, an icy horizon |
| Ark of Truth | variants named with the word "ark" or "truth" (e.g. `ark_of_truth`): an Ancient gate in aged gold, white-hot gold chevrons, a golden wormhole whose light shines out in rays around the ring |
| Origins | variants with "origins" or "1939" in their name: the Giza gate of Stargate Origins, weathered dusty stone, amber chevrons, a faded film-toned horizon |
| Pegasus | Stargate Journey Pegasus gates: slate ring, the dialed symbols light up |
| Atlantis | the `pegasus_atlantis` variant, and any variant with "lantea" in its name |
| Universe | Universe gates: dark ring, white chevron lights |
| Tollan | Tollan gates: slim white ring |
| Classic | Classic gates: bronze ring |
| Infinity | variants with "infinity" in their name: the gate of the animated series *Stargate Infinity*. A cartoon gate with black ink outlines and dark claw chevrons that light lime-yellow, a white-blue whirlpool drawn with ink lines, in front of the brown gate room wall with its lime light bars |
| Legacy Hybrid | variants with "hybrid" or "legacy" in their name: amber, red and purple chevrons with a blue master chevron |
| Ori Supergate | variants named with "supergate" or the word "ori" (e.g. `ori_gate`, not "origins"); pick it with STYLE for an SGCraft 2.3 Ori supergate. A ring of 40 separate segments in space, no symbols or chevrons |
| SGCraft | gates from Greg's SGCraft |

Variants from resource packs are matched by name, so a variant called `lantea_gate` gets the Atlantis look.

### Ori Supergate

The supergate has no chevrons. Its segments light up one after another, clockwise from the top, as the address is encoded, with energy arcing between the lit segments. When the wormhole forms the whole ring glows. It is drawn against a starfield.

![Ori Supergate](../imgs/OriSupergate.png)

*Left: chevron 5 of 7 encoded. Right: the wormhole established.*

## Requirements

- **Stargate Journey**: a basic, crystal or advanced crystal interface next to the computer or on a wired modem network. Pegasus, Universe, Tollan and Classic gates need a crystal interface to dial. The local address and the caller's address need an advanced crystal interface.
- **SGCraft**: the ComputerCraft stargate interface under the gate base.
- **Lantea: Stargates**: right-click a Stargate Power Coupler Kit onto the finished controller, then put the computer against the controller (or connect it with a wired modem). Needs Lantea 0.7.7.0 or newer.
- **Just Stargate Mod**: put the computer against the gate's base block, or connect it with a wired modem. To open and close the iris from a computer, set the iris mode to OC/computer in the gate's GUI.
- An advanced computer and an advanced monitor. The programs also run on the computer's own screen.
- Optional: a speaker (alarm for incoming wormholes) and redstone alarm lights.

Mods without a ComputerCraft interface can't be driven by these programs. The Gate Room and the Hub find the gate by itself; SGCraft, Lantea and JSG all call their peripheral `stargate`, and the programs tell them apart by the methods they have.

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
| | type an address, Enter | dial it (see [address formats](#addresses)) |
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

## Addresses

Each mod writes addresses its own way. Type them like this; the point of origin is added when dialing:

| Mod | Example |
|---|---|
| Stargate Journey, Lantea | `26 6 14 31 11 29` or `-26-6-14-31-11-29-` (symbols 1-38; Lantea's 7th symbol is the galaxy) |
| SGCraft | `WLDQ-DQB-MT` (7 or 9 letters/digits) |
| Just Stargate Mod | `Crater, Virgo, Bootes, Centaurus, Libra, Serpens Caput` (symbol names, separated by commas) |

A gate only dials addresses in its own format; the programs say so if you pick the wrong one.

## Shared address book

The Gate Room, the Hub and the Personal Dialer all read `/dialer_addresses.db`. On an advanced computer you can run the Gate Room on the monitor and the dialer in a second tab (`bg dialer`). Each entry has:

- `name`, `note`
- `address`: numbers (Stargate Journey, Lantea), a string of letters (SGCraft), a list of symbol names (JSG), or nothing for a planned destination
- `group` and `color` (used by the Hub)

## The sgc library

`sgc/` can be used by your own programs:

| Module | What it does |
|---|---|
| `sgc.gate` | finds the gate interface (Stargate Journey, SGCraft, Lantea or JSG), reads its state, turns events into simple messages, dials, iris |
| `sgc.lantea`, `sgc.jsg` | the Lantea and JSG parts of `sgc.gate` |
| `sgc.address` | parses, formats and compares the three address formats |
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

- The computer interface doesn't report whether a gate is Milky Way, Pegasus, Universe or an Ori supergate, so every SGCraft gate starts with the SGCraft look. Tap **STYLE** in the Gate Room (or pick a theme in the dialer's gate info) to match a Pegasus, Universe or Ori Supergate gate. The choice is remembered.
- ZPMs feeding the gate are shown next to its energy.
- Incoming wormholes are recognised from the gate's dialing direction, which 2.3 reports instead of the old `sgDialIn`/`sgDialOut` events.
- Dialing errors are shown as text ("No stargate at that address", "Not enough energy to dial"...) instead of SGCraft's message keys.

## Lantea notes

- Lantea numbers its Milky Way symbols like Stargate Journey (1-38, point of origin 0), so the same address works in both mods' notation. A same-galaxy address is the first six symbols; another galaxy needs all seven and a Range Crystal.
- The program turns the ring to each symbol and locks it (`encodeSymbol`); locking the point of origin reaches out.
- Pegasus gates have no ring to turn, so Lantea doesn't let computers dial them. The Gate Room still shows them, their chevrons and wormholes.
- Energy is shown in EU, as Lantea reports it.

## Just Stargate Mod notes

- JSG addresses are symbol names. The program sends the whole address to the gate (`dialAddress`), lets the gate dial it, then opens it (`engageGate`) if it did not open by itself.
- JSG's iris can only be toggled by a computer when its mode is OC/computer.
- JSG Movie gates get the Movie look; Pegasus, Universe and Tollan gates get theirs.

## Notes

- Dialing reads the gate state from events and also polls it, so a missed event does not leave the screen stuck.
- On an SGCraft gate the inner ring animation is drawn by the program; SGCraft does not report the ring position.
- The Gate Room changes the colour palette of its monitor and restores it when it quits.
- Not tested in a live game yet. The programs were run against simulated Stargate Journey, SGCraft (original and 2.3), Lantea: Stargates 0.7.7.0 and JSG 1.20.1 interfaces. Those were built from each mod's source code, or for Lantea and JSG from the method and event names in the released jars.
