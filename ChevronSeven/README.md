# Chevron Seven

A stargate mod for **Minecraft 1.20.1 (Forge)**, written from scratch: its own gate, Dial Home Device and iris, with all textures and symbols drawn by its own script. It needs no other stargate mod. With [CC: Tweaked](https://modrinth.com/mod/cc-tweaked) installed, the gate is a computer peripheral that the [Gate Room, Network Hub](../StargateCommand/) and [Personal Dialer](../PersonalDialer/) drive just as they drive Stargate Journey.

![Chevron Seven](../imgs/ChevronSeven.jpg)

## The gate

- A ring seven blocks across, with a symbol track that turns to each symbol, nine chevrons, and an event horizon that ripples and swirls.
- Dialing locks seven chevrons: six symbols, then the point of origin. The ring turns one way, then the other, and the top chevron engages each symbol.
- The wormhole opens with a kawoosh. The vortex vaporises anything standing in front of the gate (you can turn this off).
- Step into the event horizon of the gate you dialed from and you come out of the other gate, facing out, at the same height and side, even in another dimension. Travel is one way, from the dialing gate. The receiving gate's horizon doesn't send you back. The bottom of the ring is a solid block. Gates in gate fields and at the planet sites have a step in front, so you can walk in; for a gate you place yourself, put stairs in front of it, or jump in.
- The wormhole closes by itself after five minutes (configurable, up to 38 minutes). Only the dialing gate can close it, unless you allow it in the config.
- Both gates keep their chunks loaded while they are connected, so a wormhole to a planet nobody is on still opens and closes, and an open wormhole survives a server restart.
- The ring lights up its surroundings while a wormhole is open.
- A comparator next to the stargate block reads how many chevrons are locked.

Right-click any part of the ring to see the gate's address. Every gate gets its own random address of six different symbols from 1 to 38; the point of origin, symbol 0, is the same for every gate and is dialed last.

## Blocks and items

| | What it does | Recipe |
|---|---|---|
| **Stargate** | Place it on the ground, facing you: it needs a clear 7 × 7 space. You place the bottom middle block; the rest of the ring builds itself. Break any part to pick the whole gate up again. | iron blocks in the corners, eyes of ender on the sides, a lodestone in the middle |
| **Dial Home Device** | Right-click it to dial the nearest gate within 16 blocks. Press six symbols, then the big red button (or the point of origin). Press the red button again to close the wormhole; while dialing, it cancels the dial. With several gates in range, the arrows by the title pick which one it dials from. Since 1.3.0 it looks like the Carter Addon Pack's DHD: a round orange top about two blocks across, with two rings of glyph keys and a blue dome. As its gate dials, the keys of the locked symbols light up one by one in the gate look's chevron colour, and the dome glows while the wormhole is open. | redstone block on top, gold ingot, compass, gold ingot in the middle, smooth sandstone along the bottom |
| **Gate Iris** | Use it on a gate to fit an iris: curved blades that spiral shut. Close it from the DHD, a computer or a command. Travelers from the other side hit a closed iris and bounce back, and it stops the kawoosh. | iron ingots around an iron trapdoor |
| **Gate Look Crystal** | Use it on a gate to change how it looks (see [gate looks](#gate-looks)): each use gives the next look, sneak to go back. It isn't used up. | an amethyst shard, nether quartz and glowstone dust |
| **Gate Address Book** | Use it to read the address of every planet's gate (see [planet gates](#planet-gates)). | a book and an eye of ender |

## Gate looks

![The gate looks](../imgs/GateLooks.jpg)

*Every look, each on a gate platform with its wormhole open, in a Minecraft 1.20.1 client.*

Every gate can have its own look: its ring and symbol track, the colour of its chevrons and symbols, its event horizon and its iris all change with it. A new gate starts with the SG-1 look. Change it with the **Gate Look Crystal** or `/chevron7 look <pos> <look>`.

| Look | |
|---|---|
| `sg1` | grey stone, orange chevrons, blue water |
| `movie` | darker, browner stone, deep orange chevrons |
| `origins` | the weathered 1939 gate: chipped sandstone-coloured stone |
| `continuum` | the frozen gate: pale stone with frost |
| `ark` | gold, with a golden wormhole (Ark of Truth) |
| `atlantis` | blue-grey stone, blue chevrons (Pegasus) |
| `universe` | dark grey, white chevrons, a starry-white horizon (Destiny) |
| `infinity` | the animated series: a pale ring with black ink outlines, orange chevrons, a flat bright cyan wormhole with white streaks |
| `ori` | nearly black, pale blue chevrons |
| `tollan` | grey-green, green chevrons, a green wormhole |
| `goauld` | bronze, amber chevrons, an orange wormhole |
| `wraith` | purple-grey, violet chevrons, a violet wormhole |
| `crimson` | dark red, red chevrons, a red wormhole |

`/chevron7 looks` lists them. Computers see the look as the gate's variant (`chevron7:infinity`, for example), so the [Gate Room and Personal Dialer](../StargateCommand/) pick their matching style by themselves. Looks are only colours and textures: the gate works the same in every one.

## Gate platforms and the gate room

![Gate platforms](../imgs/GatePlatforms.jpg)

*Left: `/chevron7 platform` on flat ground. Right: the gate on Mars, which now stands on a platform too. Both from a Minecraft 1.20.1 client.*

`/chevron7 platform <pos> [direction] [look] [style]` builds a gate on a raised stone dais: two steps up the front, the gate's own step on top, a lantern on a post at each corner and a DHD in front, on a paved plaza. The style is the stone it's made of: `stone`, `deepslate`, `sandstone` or `blackstone`. Without a direction the gate faces whoever runs the command. Planet sites are built this way now.

![The Infinity gate room](../imgs/GateRoomInfinity.jpg)

*`/chevron7 gateroom`, with the wormhole open, in a Minecraft 1.20.1 client.*

### The Carter Addon Pack pedestal

![The CAP pedestal](../imgs/CapPedestal.jpg)

*Left: an SG-1 gate on a CAP pedestal with its wormhole open. Middle: its DHD, with the keys of the dialed symbols lit and the dome glowing. Right: the Infinity gate it reached, on a pedestal of its own. In a Minecraft 1.20.1 client.*

After the dial sequence of the Carter Addon Pack for Garry's Mod: `/chevron7 platform <pos> [direction] [look] cap` builds the gate on a sloped stone pedestal (three layers that step in towards the top, stairs down every side) with a red carpet up the middle to the gate's step, the round DHD at the foot of the carpet, and a red floor around it all.

`/chevron7 pedestal <pos> [direction] [small|large]` builds the same pedestal and carpet with no gate, so a gate of another mod can stand on it. `small` fits the 7-wide gates of Chevron Seven, Stargate Journey and Lantea: Stargates; `large` fits JSG's bigger ones. It answers with where the gate's base (the bottom middle of the ring) goes; place your gate there, facing the way the carpet comes up.

`/chevron7 gateroom <pos> [direction]` builds a gate room after the animated series: an Infinity-look gate on a base at the top of a copper ramp with red rails, a pale halo on the wall behind it and yellow and lime light bars fanned out around it. The room is lit and open at the front, and has a DHD by the ramp.

## Gate fields

![Gate field](../imgs/GateField.jpg)

*A gate field in a Minecraft 1.20.1 client: five gates around a clearing, with the DHD in the middle choosing which gate dials. Bottom right: the middle gate has dialed the leftmost one.*

A gate field is five gates on an arc around a clearing, each at the end of a dirt path with a step up to it, with one DHD in the middle that can dial from any of them. The outer gates turn towards the middle as far as a gate can (gates face north, east, south or west).

- They appear by themselves, rarely, in plains, sunflower plains, meadows and savannas, on flat dry ground. Every gate has its own address.
- An operator can build one anywhere: `/chevron7 field <pos> [direction] [gates]`, e.g. `/chevron7 field ~ ~ ~ north 5`. The gates stand 13 blocks from `<pos>` in that direction; 1 to 7 gates.
- Turn the natural ones off with `gate_fields = false` in the config.

## Planet gates

![The gate on Mars](../imgs/PlanetGateMars.jpg)

*Mars in a Minecraft 1.20.1 client with Ad Astra 1.15.21: the planet's gate on its paved pad (1.1), with a wormhole open from a gate on Earth. Since 1.2.0 the gate stands on a [platform](#gate-platforms-and-the-gate-room).*

With [Ad Astra](https://modrinth.com/mod/ad-astra) installed, the Moon, Mars, Venus, Mercury and Glacio each have a gate: a stone platform near 8, 6 with the gate on top, stairs up to it and a DHD. Planets visited before 1.2.0 keep their paved pad.

- Every planet's gate has its own address, fixed for the world. The **Gate Address Book** (or `/chevron7 planets`) lists them.
- You can dial a planet before anyone has been there: the first wormhole to it generates the planet's gate. A gate on Earth can dial Mars directly.
- Ad Astra's planets have no air to breathe, except Glacio. Wear a space suit before you step through.
- Turn planet gates off with `planet_gates = false` in the config.

Galacticraft isn't available for Forge 1.20.1 (only the 1.12.2 Galacticraft Legacy is), so it has no planet gates. Other mods' planets can get gates with a data pack that adds their biomes to the `#chevron7:has_planet_gate` biome tag.

## Computers (CC: Tweaked)

Put a computer against any block of the ring, or connect one with a wired modem. The peripheral type is `chevron7_stargate`.

| Method | |
|---|---|
| `getLocalAddress()` | this gate's address, e.g. `{12, 5, 30, 21, 7, 1}` |
| `engageSymbol(symbol)` | turns the ring to the symbol and locks a chevron; dial 0 last to open the wormhole |
| `dialAddress(address)` | dials a whole address, e.g. `dialAddress({12, 5, 30, 21, 7, 1})` |
| `disconnectStargate()` | closes the wormhole, or stops a dial |
| `getChevronsEngaged()`, `getDialedAddress()`, `getConnectedAddress()` | chevrons locked, symbols dialed, the address on the other side |
| `isStargateConnected()`, `isStargateDialingOut()`, `isWormholeOpen()`, `getOpenTime()` | the connection |
| `getGateState()` | `idle`, `dialing`, `opening`, `open`, `closing` or `resetting` |
| `getRotationDegrees()`, `getCurrentSymbol()`, `isCurrentSymbol(symbol)` | the symbol ring |
| `getIris()`, `openIris()`, `closeIris()`, `getIrisProgressPercentage()` | the iris |
| `getRecentFeedback()` | the last result as a code and a name, e.g. `-5, "invalid_address"` |
| `sendStargateMessage(text)` | the other gate gets a `stargate_message_received` event |
| `getStargateType()` | `"chevron7:stargate"` |

Events (the first argument is the peripheral's name): `stargate_chevron_engaged` (chevrons, chevron, incoming, symbol), `stargate_rotation_started`, `stargate_rotation_stopped`, `stargate_outgoing_wormhole` (address), `stargate_incoming_wormhole` (address), `stargate_disconnected` (code, reason), `stargate_reset` (code, reason), `stargate_deconstructing_entity` and `stargate_reconstructing_entity` (type, name, uuid), `iris_thud` (type, name, uuid) and `stargate_message_received` (text).

The names, the feedback codes and the events follow Stargate Journey's crystal interface, so programs written for that mostly work here as they are.

## Commands

For operators:

```
/chevron7 list                          every gate and its address
/chevron7 address <pos>                 the address and state of a gate
/chevron7 dial <pos> <address>          dial, e.g. /chevron7 dial ~ ~ ~5 12-5-30-21-7-1
/chevron7 close <pos>
/chevron7 iris <pos> open|close
/chevron7 field <pos> [direction] [gates]   build a gate field (see above)
/chevron7 planets                       the planets' gate addresses
/chevron7 look <pos> <look>             change a gate's look
/chevron7 looks                         list the looks
/chevron7 platform <pos> [direction] [look] [style]   build a gate on a platform
/chevron7 gateroom <pos> [direction]    build an Infinity gate room
/chevron7 pedestal <pos> [direction] [small|large]   build a CAP pedestal for any mod's gate
```

`<pos>` can be any block of the ring.

## Config

`config/chevron7-common.toml`:

| Option | Default | |
|---|---|---|
| `max_open_seconds` | 300 | how long a wormhole stays open (10 to 2280) |
| `kawoosh_kills` | true | the kawoosh destroys what stands in front of the gate |
| `incoming_can_close` | false | the receiving gate can close the wormhole too |
| `gate_fields` | true | gate fields appear in plains, meadows and savannas |
| `planet_gates` | true | planets (Ad Astra) get a gate near 8, 6 |

## Install

Put [`dist/chevron7-1.3.0.jar`](dist/chevron7-1.3.0.jar) in the `mods` folder (client and server) of a Forge 47 / Minecraft 1.20.1 game. CC: Tweaked is optional.

## Tested

- **Dedicated Forge 1.20.1 server (47.4.29) with CC: Tweaked 1.120.2**: three gates, one of them in the Nether.
  - The `sgc.gate` adapter of the Stargate Command programs found the gate, dialed it and closed it, and read its errors. Its events arrived in order.
  - The kawoosh killed a pig standing in front of the receiving gate.
  - A pig walked through to the other gate, and another came out at the gate in the Nether.
  - A closed iris bounced a traveler back.
  - Breaking the stargate block, or any block of the ring, removed the whole gate.
- **Minecraft 1.20.1 client** with software rendering (no graphics card): the screenshots on this page come from it. The gate was dialed with `/chevron7 dial`, and then by clicking six symbol keys and the big button on the DHD screen, which opened the wormhole to the other gate.

- **Gate fields**:
  - Built with `/chevron7 field` and with `/place feature chevron7:gate_field` on the server.
  - In a newly generated normal world, with a test data pack that put a field in every eligible chunk: 237 gates around spawn, with no errors and no world-generation warnings.
  - In the client, the DHD's arrows picked the middle gate, and clicking an address on the DHD opened its wormhole to the leftmost gate.

- **Planet gates**, on a server with Ad Astra 1.15.21:
  - The address book listed the five planets and left out the orbits.
  - A gate on Earth dialed Mars before anyone had been there. The wormhole generated Mars's gate site (gate facing south, DHD on the paved pad), and a pig walked from Earth to Mars.
  - Without Ad Astra, the mod loads and the address book says there are no planets.
  - In a Minecraft 1.20.1 client, on a server set up the same way, a gate on Earth dialed Mars, and the Mars gate opened its end of the wormhole. The picture above is from that client.

- **Two players**, each in a Minecraft 1.20.1 client, on a server with Ad Astra:
  - One player jumped into the gate on Earth and came out of the gate on Mars, then jumped back through a wormhole dialed from Mars.
  - The other player, beside the Earth gate, saw the wormhole and the first player.
  - Walking straight at the gate didn't take you through, because the bottom of the ring is a block; you had to jump. 1.1.1 adds the steps below.

- **Steps (1.1.1)**, in a Minecraft 1.20.1 client on a server with Ad Astra:
  - `/chevron7 field` put stairs in front of all five gates, and Mars's gate site got a step in front of its gate.
  - A player walked, without jumping, up the step of a field gate into the wormhole and came out on Mars, then walked up the step on Mars's pad and came back.

![The steps](../imgs/GateSteps.jpg)

*Left: a gate in a gate field, with the path leading up to its step. Right: the gate on Mars, with its step on the paved pad. Both from a Minecraft 1.20.1 client.*

- **Sounds (1.1.2)**, in a Minecraft 1.20.1 client whose audio was recorded to a file:
  - Dialing plays a sound as the ring turns and each chevron locks, the kawoosh is the loudest, and closing plays a sound that fades out.
  - The hum of an open wormhole was silent beyond 7 blocks, because Minecraft's beacon hum only carries that far. 1.1.2 plays it louder so it carries about 17 blocks; it was heard at 10, 15 and 20 blocks.

- **Forests, planets and restarts (1.1.3)**, in a Minecraft 1.20.1 client on a server with Ad Astra and CC: Tweaked, starting in a dark forest. 1.1.2 had these problems, all fixed:
  - **Gate fields in a forest** went by the treetops. `/chevron7 field` set gates down on the canopy, left trunks and giant mushrooms in front of them, put the DHD on a bump and left the path too steep to walk. 1.1.3 finds the real ground under the trees, clears trees and mushrooms around each gate and along the paths (whole trees, so no trunk is left hanging), and levels the clearing and the ground in front of each step. In the same forest, a player walked from the DHD up the path into the middle gate and came out at the gate it had dialed. Natural gate fields now generate after trees; on a test world with them made very common, they generated in plains with no errors.
  - **A closed iris didn't stop a player.** The gate couldn't tell which side a player had come from (the server moves players between ticks, so where they were and where they are looked the same), so a player walked straight through the open wormhole and out behind the gate they had dialed from, with the iris at the other end shut. 1.1.3 remembers which side each player is on. A player who kept walking into the gate was held in front of it, and with the iris open the same walk took them through.
  - **A gate on a planet nobody was on never finished opening or closing.** A dimension without players stops running its gates, so the Moon's gate stayed "opening" after its wormhole closed, and every later dial to the Moon failed with "target busy". Connected gates now force-load their chunks, so both ends keep running, and a gate that was left like that is set right the next time it is dialed.
  - **An open wormhole was lost when the server restarted.** It now carries on: both gates were still open after a restart, and their open time kept counting with no player online.
  - `/chevron7 iris` now says what it is doing, and `/chevron7 address` shows whether the gate's iris is open or closed.

![A gate field in a forest, before and after](../imgs/GateFieldForest.jpg)

*Gate fields built with `/chevron7 field` in a dark forest, in a Minecraft 1.20.1 client. Left: 1.1.2, with gates up the hillside among the trunks and the DHD on a block of grass. Right: 1.1.3, with the trees cleared and the clearing level, the DHD on the path and every gate on its step.*

- **Looks, iris, platforms and the gate room (1.2.0)**, in a Minecraft 1.20.1 client on a flat test world with Ad Astra:
  - `/chevron7 platform` built 14 gates in every look and all four stone styles. Seven pairs dialed each other at once, and every look's ring, chevrons and wormhole showed as in the picture above.
  - The Gate Look Crystal stepped a gate forward through the looks with each use, and back with a sneak-use. The look is kept when the server restarts.
  - Fitted to an SG-1 and an Infinity gate, the iris closed as a spiral of curved blades, grey on the one and light blue with black ink lines on the other.
  - `/chevron7 gateroom` built the room. Dialed from it, a player walked up the copper ramp into the gate and came out at the gate on the other platform.
  - Dialing Mars generated its site as a platform, with the gate and stairs in place.

![The spiral iris](../imgs/GateIrisSpiral.jpg)

*The iris closing and shut on an SG-1 gate (left two) and an Infinity gate (right two).*

- **The CAP pedestal and DHD (1.3.0)**, in a Minecraft 1.20.1 client:
  - `/chevron7 platform … cap` built an SG-1 and an Infinity gate on pedestals, and `/chevron7 pedestal` built a small and a large one with no gate.
  - Dialing from the SG-1 gate lit the DHD's keys for the dialed symbols and made the dome glow once the wormhole was open (the middle picture above).

## Build

```
python3 tools/make_resources.py   # only after changing it: textures, symbols, models, recipes
./gradlew build
```

The jar is `build/libs/chevron7-1.3.0.jar`.

## License

MIT, see [LICENSE](../LICENSE). That covers the textures and symbols too: they are original, drawn by `tools/make_resources.py`.
