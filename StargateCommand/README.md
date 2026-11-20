# Stargate Command

Three monitor programs, a GDO for pocket computers and a shared library for ComputerCraft stargates:

- **Gate Room**: an SGC style gate room screen. The gate is drawn in the look of its series, the chevrons lock one by one, the inner ring turns, the wormhole forms with a kawoosh and the iris closes over it.
- **Gate Network Hub**: a touch screen of destination cards. Each card has its own portal colour and a tab (Milky Way, Pegasus, Crossover...). Tap a card to dial it.
- **[Dial Home Device](#dial-home-device)**: the DHD from the show on a touch screen. Press the symbols of an address on its two rings of keys, then the big dome in the middle.
- **[GDO](#gdo)**: a pocket computer turned into the team's iris code transmitter. Punch in your code at the far gate, and the Gate Room at home opens its iris.

They share one address book with the [Personal Dialer](../PersonalDialer/) and work with these mods:

| Mod | Minecraft | What the computer needs | Dials |
|---|---|---|---|
| **Stargate Journey** | 1.20.1 | a basic, crystal or advanced crystal interface | every gate type |
| **SGCraft** (Greg Ewing's, and SGCraft 2.x, the "Stargate Network" mod) | 1.7.10 to 1.12.2 | the ComputerCraft stargate interface | every gate |
| **Lantea: Stargates** 0.7.7.0+ | 1.20.1 (Forge), 1.21.1 (NeoForge) | a Stargate Power Coupler Kit on the gate controller | Milky Way gates (Pegasus gates can be watched, not dialed) |
| **Just Stargate Mod** (JSG) | 1.20.1 | the gate's base block (it is a CC: Tweaked peripheral) | every gate |
| **[Chevron Seven](../ChevronSeven/)** | 1.20.1 | any block of the gate ring (it is a CC: Tweaked peripheral), or its SG Computer Interface | every gate, including its Infinity and Stargate Network gates |

On OpenComputers (SGCraft, and Just Stargate Mod for 1.12.2), use [gatedial](../OpenComputers/) instead. It reads and writes the same address book, iris codes and gate log.

![Gate Room](../imgs/GateRoom.png)

*Gate Room on a 4x3 monitor. Top: dialing Abydos on an SG-1 gate, and the open wormhole. Bottom: the iris closed over an incoming wormhole, and an SGCraft gate with a 9-symbol address. These screens were rendered from a headless CC: Tweaked test harness with simulated gates, not captured in-game.*

## Gate looks

The look is picked from the gate type and its Stargate Journey variant. You can also cycle it with the **STYLE** button.

![Gate styles](../imgs/GateStyles.png)

| Style | Used for |
|---|---|
| Milky Way | Stargate Journey Milky Way gates |
| SG-1 | the `milky_way_sg-1` and `milky_way_promo` variants |
| SGC Computer | pick it with STYLE (any gate), or a variant with "computer" in its name. The SGC's dialing computer screen, see [below](#sgc-computer) |
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
| Stargate Network | Chevron Seven's Stargate Network gate: a dark steel-blue ring of letters with blue chevrons |
| Carter Addon Pack | pick it with STYLE, or a variant named "cap" or "carter". After the Garry's Mod addon: the gate a little smaller, on a stepped grey pedestal with a red carpet, under the sky, with the round orange DHD and its blue dome in front |

![The Carter Addon Pack style](../imgs/GateRoomCAP.png)

*The Gate Room's Carter Addon Pack style with a wormhole open, rendered from the test harness.*

Variants from resource packs are matched by name, so a variant called `lantea_gate` gets the Atlantis look.

### SGC Computer

The gate as the SGC's dialing computer shows it: teal lines on a dark screen, with corner brackets, a crosshair in the middle, the symbol track turning with the ring and chevrons that fill in as they lock. As each chevron is encoded, its symbol comes up big across the gate, then shrinks away into its numbered box beside it, where it stays until the gate closes. The wormhole is drawn as rings of light running out from the middle, and the iris as a line drawing of its blades.

![The SGC Computer style](../imgs/GateRoomSGCComputer.png)

*Top: chevron 2's symbol over the gate as it is encoded, and chevron 4's with the first four in their boxes. Bottom: the wormhole established, and an incoming wormhole against the closed iris. On a 4x3 monitor, rendered from the headless test harness.*

The symbols are line figures drawn by the program, like constellations: each symbol always gets the same one, and the point of origin is a pyramid under a sun. They are not the mod's glyphs or the show's. Every gate type has them: numbers, SGCraft letters and JSG's symbol names each get a figure of their own.

On a monitor four blocks high the boxes stand in one numbered column; on one three blocks high they are in two columns. Smaller screens (under 30 lines) list the chevrons as text, as the other styles do.

### Ori Supergate

The supergate has no chevrons. Its segments light up one after another, clockwise from the top, as the address is encoded, with energy arcing between the lit segments. When the wormhole forms the whole ring glows. It is drawn against a starfield.

![Ori Supergate](../imgs/OriSupergate.png)

*Left: chevron 5 of 7 encoded. Right: the wormhole established.*

## Requirements

- **Stargate Journey**: a basic, crystal or advanced crystal interface next to the computer or on a wired modem network. Pegasus, Universe, Tollan and Classic gates need a crystal interface to dial. The local address and the caller's address need an advanced crystal interface.
- **SGCraft**: the ComputerCraft stargate interface under the gate base.
- **Lantea: Stargates**: right-click a Stargate Power Coupler Kit onto the finished controller, then put the computer against the controller (or connect it with a wired modem). Needs Lantea 0.7.7.0 or newer.
- **Just Stargate Mod**: put the computer against the gate's base block, or connect it with a wired modem. To open and close the iris from a computer, set the iris mode to OC/computer in the gate's GUI.
- **Chevron Seven**: put the computer against any block of the gate ring, or connect it with a wired modem. Or put it next to an SG Computer Interface within 6 blocks of the gate: the programs then treat the gate as an SGCraft gate and dial letter addresses such as `1KA0-9KT-HY`.
- **LanteaCraft** (NeoForge 1.21.1, 0.2.5 or newer): put the computer against the gate's base block, or connect it with a wired modem.
- An advanced computer and an advanced monitor. The programs also run on the computer's own screen.
- Optional: a speaker (alarm for incoming wormholes) and redstone alarm lights.

Mods without a ComputerCraft interface can't be driven by these programs. The Gate Room and the Hub find the gate by itself; SGCraft, Lantea, LanteaCraft and JSG all call their peripheral `stargate`, and the programs tell them apart by the methods they have. Chevron Seven's gate (`chevron7_stargate`) speaks the same language as Stargate Journey's crystal interface.

## Installation

With HTTP enabled in the CC: Tweaked config:

```
wget run https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/StargateCommand/install.lua
```

This downloads `gateroom.lua`, `hub.lua`, `dhd.lua`, `dialer.lua`, `idc.lua`, `gdo.lua` and the `sgc` folder into the current folder. Run it again to update; your address book is kept.

To start one of them when the computer boots, add its name:

```
wget run https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/StargateCommand/install.lua gateroom
```

The same goes for `hub`, `dhd`, `dialer`, `gdo` (on a pocket computer) and `relay` (`gdo relay` at a gate).

Without HTTP, copy `gateroom.lua`, `hub.lua`, `dhd.lua`, `gdo.lua` and the whole `sgc` folder to the computer. The programs need `sgc` next to them.

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
| `LOG` in the destination list | Ctrl+L | the gate log |
| | Ctrl+Q | quit |

Ctrl+D and Ctrl+L close their list again.

The dialing computer panel shows each chevron as it is encoded and locked, the destination or caller, how long the wormhole has been open, the gate's energy and the iris. Gates dialed from a DHD show up the same way.

An incoming wormhole flashes the screen red ("OFFWORLD ACTIVATION"), sounds an alarm on an attached speaker and can power a redstone line for alarm lights.

Settings at the top of `gateroom.lua`:

- `interfaceName`: which gate interface to use if the computer reaches several
- `textScale`, `frameTime`: monitor detail and animation speed (raise `frameTime` on a busy server)
- `fastDial`: engage symbols directly instead of turning the Milky Way ring
- `autoIris`: close the iris when another gate dials in. Off by default, because your own team coming home hits the iris too. On Stargate Journey the kawoosh destroys an iris that is closed when the wormhole forms, so there the Gate Room keeps the iris open (opening it if needed) until the wormhole is open, then closes it: it shuts within about three seconds, and survives
- `alarmSide`: redstone side powered while an incoming wormhole forms, e.g. `"back"`
- `klaxon`: speaker alarm on or off
- `autoClose`: close an outgoing wormhole this many seconds after someone steps through (0 = never)
- `irisCodes`: check iris codes from the gate that dialed in (on by default), `codesFile`: where the trusted codes are kept
- `gdoRelay`: with a wireless or ender modem on the computer, pass codes from travellers' [GDOs](#gdo) through the open wormhole (on by default)
- `logFile`, `logSize`: the gate log and how many entries it keeps

## Iris codes and the gate log

Like the GDO in the show: the team dialing home sends a code through the wormhole, and the Gate Room opens the iris if the code is trusted.

1. On the home gate's computer, trust the code with the `idc` program and set `autoIris = true` in `gateroom.lua`, so the iris closes when a wormhole comes in.
2. On the computer that dials home, give the home gate's address book entry the same code: the **Iris code** field in the Personal Dialer's edit form.
3. Dial home. The Personal Dialer or the Gate Room sends the code as soon as the wormhole opens. The Gate Room at home opens the iris and answers "accepted"; an unknown code gets "rejected", and the iris stays shut.

```
idc                     list the trusted codes
idc add 1234 SG-1       trust code 1234, under the name SG-1
idc remove 1234         stop trusting it
idc log                 print the gate log
```

![Iris codes and the gate log](../imgs/IrisCodes.png)

*Top left: a trusted code arrives during an incoming wormhole and the iris opens. Top right: the gate log. Bottom left: the destination list leaves out an entry tied to another gate. Bottom right: our code accepted at the other end. Rendered from the headless test harness.*

Codes are 1 to 16 letters, digits or dashes. They travel as gate messages (`IDC:1234`, answered by `IDC:ACCEPTED SG-1` or `IDC:REJECTED`), so both gates need a mod that sends messages: Stargate Journey's crystal interfaces, SGCraft and Chevron Seven do. Lantea and JSG gates don't, so their computers can't send or check codes.

The Gate Room keeps a log in `gate_log.db`: incoming and outgoing wormholes with how long they stayed open, failed dials, travellers and codes, each with the in-game day and time. See it with `LOG` in the destination list, Ctrl+L, or `idc log`.

## GDO

In the show, a team coming home sends its code from the GDO on its wrist and the SGC opens the iris. The `gdo` program makes an advanced pocket computer into one, for a team that dialed home from a DHD, or with no address book entry to send the code for them.

```
gdo                 the GDO
gdo send 600        send a code from the command line and print the answer
gdo relay           pass GDO codes through the gate at this computer
```

![The GDO](../imgs/GDO.png)

*The GDO on a pocket computer: code 600 typed in, sent through the wormhole, accepted with the SGC's iris open, and an unknown code rejected. Rendered from the headless test harness, with a simulated Gate Room at the other end.*

A pocket computer can't reach through a wormhole. The GDO radios the computer at the gate you are standing by, and that computer sends the code through the open wormhole as a gate message: the same `IDC:600` the dialing computer sends. The Gate Room at the other end checks it against its trusted codes, opens the iris and answers. The answer comes back the same way, and the GDO shows it.

What you need:

- **The GDO**: an advanced pocket computer with a wireless or ender modem (craft the pocket computer with the modem). `install gdo` starts it whenever the pocket computer is switched on.
- **The gate you dial home from**: a computer with the gate interface and a wireless or ender modem, running the Gate Room or the Personal Dialer (both relay by themselves, see `gdoRelay`), or `gdo relay`. On Stargate Journey that's a crystal or advanced crystal interface; a basic interface can't send messages. The Personal Dialer relays only when the `sgc` folder is next to it, as the Stargate Command installer leaves it.
- **At home**: the Gate Room, with your code trusted (`idc add 600 SG-1`) and `autoIris = true` so the iris is shut when you call.

Using it:

1. Dial home, then stand near the gate's computer: within the wireless modem's range (64 blocks; more high up). The bars at the top show how close the gate is, and the bottom line of the LCD names it and says whether its wormhole is open.
2. Type your code on the keypad or the keyboard: up to 16 letters, digits or dashes.
3. Press **SEND** (or Enter). The GDO remembers the last code it sent, so next time SEND alone does it. **CLR** (Delete) clears, Backspace takes back one character, Ctrl+T switches the GDO off.

| LCD | |
|---|---|
| `SEARCHING`, `NO GATE` | no gate's computer heard; the line below says what's missing |
| `ENTER CODE`, `MEM` | ready; `MEM` shows the code it remembers |
| `AWAIT REPLY` | the code went through; waiting for the other side |
| `IRIS OPEN` | accepted: the way is open |
| `REJECTED` | not a trusted code: their iris stays shut |
| `NOT SENT` | no wormhole, or that gate can't send codes; the line below says why |
| `NO REPLY` | the other side didn't answer: no Gate Room there, or `irisCodes` is off |

The GDO talks to the nearest gate with an open wormhole, so at a gate field with several gates, stand by the one you dialed from. It doesn't reach gates in another dimension, even with an ender modem: a code goes through the wormhole, not around it.

Codes work wherever iris codes work: Stargate Journey crystal interfaces, SGCraft and Chevron Seven. LanteaCraft gates take codes only from LanteaCraft's own GDO item, and Lantea and JSG 1.20.1 gates can't send messages, so the GDO says the gate can't send codes. `gdo` also runs on an advanced computer; with a speaker attached, keys click and the answer chimes or buzzes. Pocket computers take one upgrade, so a pocket GDO has the modem and no speaker.

For your own programs: relays listen on modem channel 2427. The messages are described at the top of `sgc/gdo.lua`, and `sgc.gdo`'s relay can be added to any program that has an `sgc.gate`.

The GDO, `gdo relay` and the Gate Room's and Personal Dialer's relays were tested in the headless test harness: a GDO sending through `gdo relay`, a Gate Room and a Personal Dialer, trusted and unknown codes, a basic interface, a GDO on another world, the wormhole closing while the GDO waits, and a relay computer with no label (the GDO names its gate by the gate's address). They haven't been tried in a game yet.

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

## Dial Home Device

```
dhd              first advanced monitor (or the computer screen if there is none)
dhd monitor_3    a specific monitor
dhd term         the computer screen
```

![The Dial Home Device](../imgs/DHD.png)

*Top: dialing Abydos on a Milky Way gate, with three chevrons locked and the fourth going in, and the wormhole open with Abydos's iris code sent. Bottom: a Pegasus gate with Atlantis's seven symbols locked, and the Infinity look with the wormhole open. On a 4x3 monitor, rendered from the headless test harness.*

The DHD from the show: two rings of symbol keys around a big dome. Press the symbols of an address, then the dome.

- On **Stargate Journey**, **Chevron Seven** and **Lantea: Stargates** gates, each key locks its chevron as soon as you press it, like a real DHD, and the dome engages the point of origin. On a Stargate Journey basic interface the ring turns to each symbol first, so a key takes a few seconds.
- On **SGCraft**, **LanteaCraft** and **Just Stargate Mod** gates, a computer can only dial a whole address. The keys light up as you press them, and the dome dials the address. Touch the last key again to take it back. While the gate dials, the keys it hasn't locked yet blink.
- When the wormhole is open the dome is lit, and pressing it closes the wormhole.
- **CLEAR** stops dialing and lets the gate drop its chevrons. **IRIS** opens or closes the iris.

The keys match the gate: 38 for a Milky Way gate, 35 for a Pegasus or Universe gate (the point of origin is the dome), the 36 letters and digits of SGCraft, LanteaCraft's 38 glyphs (7 to 9 of them in an address; 7 or 9 on LanteaCraft for 1.7.10, once its support from PR #29 is in), or JSG's symbol names. Each key has its number, letter or a short name ("Crat" for Crater, "LeoM" for Leo Minor, "CaP" for Ca Po, "G5" for Glyph 5) and a line figure from `sgc.glyphs`. The figures are made up by the program, as in the Gate Room's SGC Computer look; they aren't the mod's glyphs, so go by the numbers and names.

The panel beside the DHD shows the gate, what it's doing, the address so far one chevron per line, and the address book's name for it ("To Abydos"). An incoming wormhole lights the caller's symbols, names the caller and locks the keys. If someone dials at the gate's own DHD block, or from another computer, the keys light up with it, and you can carry on from the screen.

The arrows at the top of the panel change the look: **Milky Way** (sand-coloured keys, amber glow, red dome), **Pegasus** (slate, blue), **Universe** (dark, white), **Carter Addon Pack** (orange, blue dome), **Infinity** (pale blue-grey, lime) and **LanteaCraft** (charcoal with pale carved symbols, amber light and an orange-red dome, after LanteaCraft's own DHD). It starts in the gate's own look, LanteaCraft's for LanteaCraft gates, and remembers your choice.

A round DHD needs a monitor at least 4 blocks wide and 3 high. Smaller monitors, and the computer's own screen, show the keys as a keypad with a DIAL button for the dome:

![The DHD with JSG names, and as a keypad](../imgs/DHDGates.png)

*Left: a JSG gate, its keys named after the constellations. Right: an SGCraft gate on the computer's screen, dialing Avalon with four chevrons locked. Rendered from the test harness.*

| Keyboard | |
|---|---|
| numbers, letters or names | press that key. A number goes in when no other key starts with it, or after a space; a name goes in after Enter or a comma (`crat`, `leo m`) |
| Enter | the dome |
| Backspace | take back a typed character, or the last key on an SGCraft, LanteaCraft or JSG gate |
| Delete | CLEAR |
| Tab | next look |
| Ctrl+I, Ctrl+Q | iris, quit |

When the wormhole opens to an address book entry with an [iris code](#iris-codes-and-the-gate-log), the DHD sends the code, as the Gate Room does. With a wireless or ender modem it is also a [GDO](#gdo) relay. It leaves checking incoming codes to the Gate Room.

Settings at the top of `dhd.lua`: `interfaceName`, `textScale`, `look` (fix the look: `"milky_way"`, `"pegasus"`, `"universe"`, `"carter"`, `"infinity"` or `"lanteacraft"`), `sendCodes`, `gdoRelay`, `clicks` (key clicks on an attached speaker), and how long to wait for the gate.

What it can't do:

- Lantea's Pegasus gates, and Stargate Journey's Pegasus, Universe, Tollan and Classic gates on a basic interface, can't be dialed by any computer program. The DHD says so.
- Chevron Seven's Stargate Network gate, through its ring: there the gate numbers its letters, so connect it through its SG Computer Interface instead. The DHD then dials it like an SGCraft gate. Chevron Seven's other gates take six symbols and the dome.
- A locked chevron can't be taken back on its own, as with a real DHD. CLEAR drops them all.

The DHD has only been tried in the headless test harness, not in a game yet. There, it dialed by touch and by keyboard on simulated Stargate Journey gates (advanced crystal, crystal and basic interfaces), Chevron Seven, Lantea, SGCraft and LanteaCraft gates, and JSG's Milky Way, Pegasus and Universe gates. Other things that worked there: invalid and unfinished addresses, a symbol pressed twice, CLEAR in the middle of a key, an incoming wormhole, a gate dialed from its own DHD block, the interface removed and put back, every look, and screens from 26x20 to 165x81.

The Stargate Journey calls were checked against Stargate Journey 0.6.54's computer code. `engageSymbol` encodes a symbol as the gate's own DHD would. Every interface tier, basic included, sends the symbol with each chevron, which is how the keys follow the gate's DHD block.

The JSG key names are copied from JSG 5.1.2.0's own symbol lists, and checked against them letter for letter. On Milky Way gates they are the 37 constellations, on Pegasus gates the 35 Pegasus names, and on Universe gates `Glyph 1` to `Glyph 36`. JSG's computer methods look names up without regard to case, and they report Universe symbols by those names, which is why the keys use them. The points of origin, Point of Origin, Subido and Glyph 17, are the dome.

## Addresses

Each mod writes addresses its own way. Type them like this; the point of origin is added when dialing:

| Mod | Example |
|---|---|
| Stargate Journey, Lantea, Chevron Seven | `26 6 14 31 11 29` or `-26-6-14-31-11-29-` (symbols 1-38; Lantea's 7th symbol is the galaxy) |
| SGCraft | `WLDQ-DQB-MT` (7 or 9 letters/digits) |
| LanteaCraft | `S9X-EGA` (7 to 9 glyphs, typed exactly as the gate shows them: `-` and `+` are glyphs) |
| Just Stargate Mod | `Crater, Virgo, Bootes, Centaurus, Libra, Serpens Caput` (symbol names, separated by commas) |

A gate only dials addresses in its own format; the programs say so if you pick the wrong one.

## Shared address book

The Gate Room, the Hub, the DHD and the Personal Dialer all read `/dialer_addresses.db`. On an advanced computer you can run the Gate Room on the monitor and the dialer in a second tab (`bg dialer`). Each entry has:

- `name`, `note`
- `address`: numbers (Stargate Journey, Lantea), a string of letters (SGCraft, LanteaCraft), a list of symbol names (JSG), or nothing for a planned destination
- `group` and `color` (used by the Hub)
- `idc`: an [iris code](#iris-codes-and-the-gate-log) to send after the wormhole opens
- `home`: the local address of one gate. The entry is listed only on computers at that gate, for bases with several gates. Set it with **Only list it at this gate** in the Personal Dialer's edit form

## The sgc library

`sgc/` can be used by your own programs:

| Module | What it does |
|---|---|
| `sgc.gate` | finds the gate interface (Stargate Journey, SGCraft, Lantea, LanteaCraft or JSG), reads its state, turns events into simple messages, dials, iris |
| `sgc.lantea`, `sgc.lanteacraft`, `sgc.jsg` | the Lantea, LanteaCraft and JSG parts of `sgc.gate` |
| `sgc.address` | parses, formats and compares the three address formats |
| `sgc.book` | the shared address book |
| `sgc.idc`, `sgc.gdo` | iris codes, and the GDO's radio messages and the relay at the gate |
| `sgc.styles` | the gate looks and their palettes |
| `sgc.pixels` | a pixel canvas drawn with teletext characters (2x3 pixels per character) |
| `sgc.ring` | draws a gate on a canvas: ring, chevrons, symbols, event horizon, kawoosh, iris |
| `sgc.glyphs` | a line figure for every gate symbol (the SGC Computer style and the DHD's keys) |
| `sgc.dhd` | a DHD's keys for each gate, and locking one symbol at a time where the gate allows it |
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
- Lantea counts a chevron as locked about a second before it has finished locking, and refuses the next symbol until then ("A chevron is still locking"). The programs wait and try again.
- The gates need power: by default opening a wormhole costs 2,000,000 EU (4 FE each), and the programs report "Not enough power" otherwise. Any Forge Energy source next to the controller works; in the test a JSG Creative Capacitor powered a Lantea gate.
- Pegasus gates have no ring to turn, so Lantea doesn't let computers dial them. The Gate Room still shows them, their chevrons and wormholes.
- Energy is shown in EU, as Lantea reports it.

## LanteaCraft notes

- An address is 7 to 9 glyphs from A-Z, 0-9, `-` and `+`. The last glyph names the dimension (A the overworld, N the Nether, E the End). Because `-` is a glyph, LanteaCraft addresses are shown and typed without SGCraft's dashes.
- The gate dials the whole address by itself, about 3 seconds a chevron. The programs follow its progress and light the chevrons.
- Only the gate that dialed can close the wormhole. Closing from the other side shows LanteaCraft's reason instead.
- The gate checks iris codes itself. Each gate has one GDO code, and using a GDO on a gate pairs it and gives that gate a new code. When a traveller's GDO sends that code through the wormhole, the gate opens or closes its iris on its own. The Gate Room logs it as "accepted by the gate".
- A code the gate refuses still opens the iris if `idc` trusts it, so several teams can have codes of their own.
- A computer can't send a code; when you dial an entry with an iris code, the programs remind you to send it with your GDO.
- LanteaCraft reports no energy; the Gate Room shows whether the gate's GDO code is set instead (never the code itself).
- LanteaCraft's kawoosh kills whatever stands in front of the gate (`kawooshDeath` in its config).

## Just Stargate Mod notes

- JSG addresses are symbol names. The program sends the whole address to the gate (`dialAddress`), lets the gate dial it, then opens it (`engageGate`) if it did not open by itself.
- JSG's iris can only be toggled by a computer when its mode is OC/computer. Otherwise JSG refuses, and the Gate Room says so ("Could not close the iris: Iris mode must be set to OC").
- JSG's iris stops the kawoosh, so with `autoIris` the Gate Room closes it as soon as another gate starts dialing in.
- A gate built with `/jsg buildgate` has its base block (the bottom middle of the ring) one block into the ground: put the computer against it there, or use a wired modem.
- JSG Movie gates get the Movie look; Pegasus, Universe and Tollan gates get theirs.

## Stargate Journey notes

- Stargate Journey's kawoosh destroys an iris that is closed when the wormhole forms (in 0.6.54 a full iron iris is gone at once), so with `autoIris` the Gate Room keeps the iris open until the wormhole is open, then closes it. It shuts in about three seconds and keeps its durability.
- The gates run on Forge Energy (FE) unless the server turns energy off. BuildCraft Community Edition's engines make MJ, which the gates don't take: a Creative Engine against a crystal interface sent it nothing. BuildCraft's FE Engine turns FE into MJ, not the other way. BuildCraft's Forge Energy pipes should be able to carry FE from another mod's generator; that hasn't been tried.

## Notes

- Dialing reads the gate state from events and also polls it, so a missed event does not leave the screen stuck.
- Gate events, keys, clicks and touches are queued by a task that never calls the gate, so none are lost while the screen waits for a slow gate.
- On an SGCraft gate the inner ring animation is drawn by the program; SGCraft does not report the ring position.
- The Gate Room changes the colour palette of its monitor and restores it when it quits.
- Tested in live games with Stargate Journey 0.6.54, JSG 1.20.1 5.1.2.0 and Lantea: Stargates 0.7.7.0 (all three in one world, with CC: Tweaked 1.120.2 on Forge 1.20.1), and with LanteaCraft 0.2.5 (CC: Tweaked 1.121.0, NeoForge 1.21.1). SGCraft (original and 2.3) was tested against a simulated interface built from its source code; gatedial was tested with SGCraft in game.
- Lantea: Stargates in a live game: the Personal Dialer dialed the other gate through its Power Coupler Kit, all seven chevrons, and the Gate Room there showed the wormhole coming in. Without power both reported "Not enough power".
- Stargate Journey in a live game: dialing through the basic, crystal and advanced crystal interfaces, *Invalid address* for an address with no gate, and an incoming wormhole with `autoIris` on. The iris was opened for the kawoosh and closed after it, at full durability.
- JSG in a live game, in a world that also had JSG Decoration, Stargate Additions, Stargate Journey and BuildCraft: the Personal Dialer dialed the other gate and the Gate Room there showed it coming in. With the iris mode on OC the Gate Room closed the iris as the dial began; with another mode it said why it couldn't.

![JSG in a Minecraft 1.20.1 world](../imgs/JSGInGame.jpg)

*JSG 5.1.2.0 in a Minecraft 1.20.1 world (in the rain). Left: the gate the Personal Dialer dialed from. Middle: the gate it reached, its iris closed by the Gate Room. Right: that Gate Room's screen.*

- Chevron Seven in a live game (Forge 1.20.1, CC: Tweaked 1.120.2): the `sgc.gate` library dialed its gates both on the ring and through the SG Computer Interface, including the Stargate Network gate by its letters, and picked each gate's look from its variant.
- LanteaCraft in a live game: the Gate Room and the Personal Dialer dialed each other's gates, including an address with a `-` glyph. Closing worked from the dialing side, and the receiving side was refused with LanteaCraft's reason. The iris closed from the Gate Room. A GDO code the gate accepted opened the iris by itself; a code the gate refused but `idc` trusted opened it through the Gate Room. A player who walked through was logged.

![LanteaCraft in a Minecraft 1.21.1 world](../imgs/LanteaCraft.jpg)

*LanteaCraft 0.2.5 with CC: Tweaked in a Minecraft 1.21.1 world. Top left: the Gate Room after dialing the other gate; behind the monitor the real gate is open. Top right: the Personal Dialer at the other gate, with the wormhole coming in. Bottom left: a traveller's GDO sent the gate's own code, so the gate opened its iris and the Gate Room says so. Bottom right: the gate refused another code, which `idc` trusts as SG-1, so the Gate Room opened the iris.*
