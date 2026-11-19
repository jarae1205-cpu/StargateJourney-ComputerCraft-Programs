# Infinity Stargate for JSG

An add-on for **Just Stargate Mod (JSG) 1.20.1** (Forge): the gate from *Stargate Infinity*, which you build from its own blocks the same way you build JSG's gates.

![Infinity gate](../imgs/JSGInfinityGate.png)

*In a Minecraft 1.20.1 client with JSG 5.1.2.0 and the add-on. Top: an Infinity gate in the gate room, closed, and open with the blue swirl after a dial from the Infinity DHD. Bottom: the iris closed into its spiral; and the gate on Carter's platform at the other end of that wormhole.*

## What you get

Five blocks, in their own **Infinity Stargate** creative tab:

| Block | Recipe (shapeless) |
|---|---|
| **Infinity Stargate Base** | JSG's Milky Way Stargate Base + lime dye |
| **Infinity Stargate Ring** | JSG's Milky Way Stargate Ring + lime dye |
| **Infinity Stargate Chevron** | JSG's Milky Way Stargate Chevron + lime dye |
| **Infinity DHD** | JSG's Milky Way DHD + lime dye |
| **Orange DHD** | JSG's Milky Way DHD + orange dye |

Build them exactly like a JSG Milky Way gate: place the base first, and it shows you the diagram; then the ring and chevron blocks around it. When the ring is complete, the blocks form the gate.

The gate is JSG's Milky Way gate underneath. It has Milky Way addresses, and because its block entity is JSG's own Milky Way gate, it takes the Milky Way DHD, upgrades, the iris, energy and computers the same way. [Tested](#tested) says which of these have been tried. It is drawn with JSG's own models and animations: the turning symbol ring, the chevrons that lock and the kawoosh. Only the look changes:

- The cartoon's blue-grey metal, with ink outlines.
- A grey symbol track with dark symbols.
- Dark chevrons that glow pale cyan when locked.
- A white event horizon. Once the wormhole settles, a blue swirl turns over it, as in Carter's Addon Pack.
- A pale blue iris that closes into a spiral. It is JSG's iris, with its blades and animation; only its texture changes.

Breaking the base gives back an Infinity base, with the gate's upgrades, settings and energy kept, as JSG's own base does.

### Infinity DHD

![Infinity DHD](../imgs/JSGInfinityDHD.png)

*In a Minecraft 1.20.1 client. Top: the Infinity DHD's console; and JSG's own DHD, the Infinity DHD and the orange DHD side by side. Bottom: the screen after four symbols, and after the seventh and the dial button, with the gate in the middle lit.*

A console in the gate's blue-grey metal: a pedestal with a tilted screen of dark glass on top. On the screen:
- **The keys:** the 38 symbols in two pads, glowing cyan, white when pressed. The symbol pictures are JSG's own.
- **The gate in the middle:** the dial button. Its chevrons light as symbols are dialled, and it glows when the wormhole opens.
- **The address dialled so far,** along the top.
- **A lamp** at the bottom that lights when a control crystal is in.

Look at a key and press use, as on JSG's DHD. JSG's DHD finds the key you're looking at from where its keys are, so the Infinity DHD gives JSG its screen's key positions instead.

Underneath it is JSG's own DHD, so it works the same way: place it within a few blocks of the gate and they link. It takes the same control crystal, upgrades and fuel (sneak and use to open it), and links to Infinity gates and JSG's Milky Way, Movie and Tollan gates alike. An ordinary JSG DHD also links to an Infinity gate.

### Orange DHD

![Orange DHD](../imgs/JSGOrangeDHD.png)

*In a Minecraft 1.20.1 client: JSG's own DHD, the Infinity DHD and the orange DHD, and the orange DHD up close.*

The DHD in the style of Carter's Addon Pack:
- An orange pedestal with amber panels and yellow bands.
- A dark console with gold-edged keys that light orange.
- A turquoise dome.

It is JSG's Milky Way DHD underneath too, with JSG's model and keys, and works just like JSG's DHD.

### Commands

![Carter's platform and the Infinity gate room](../imgs/JSGInfinityBuildings.png)

*In a Minecraft 1.20.1 client: Carter's platform with the orange DHD and the Infinity gate room, closed (top) and joined by a wormhole (bottom).*

For operators. Each builds facing the way you give, or towards you:

```
/jsginfinity build <pos> [north|south|east|west]
/jsginfinity platform <pos> [north|south|east|west]
/jsginfinity room <pos> [north|south|east|west]
```

- **`build`** lays out a whole Infinity gate (base, rings and chevrons) with its base at `<pos>` and forms it, as JSG's `/jsg buildgate` does for its own gates.
- **`platform`** builds the gate on the stone pyramid from the dial sequence of Carter's Addon Pack:
  - a four-step pyramid of dark deepslate on red ground;
  - a red carpet up its front steps to the gate;
  - the orange DHD at the foot of the steps, linked to the gate.
- **`room`** builds the gate room of *Stargate Infinity*:
  - the gate on a base at the top of a brown ramp with hot-pink rails;
  - orange-brown walls, with a pale halo round the gate and yellow and lime light bars fanned out round that;
  - a lit ceiling, open at the front;
  - the Infinity DHD beside the ramp, linked to the gate.

For `platform` and `room`, `<pos>` is the ground under the middle of the gate, where you'd stand. They clear the space they need first (`platform` about 23 × 21 blocks, `room` 27 × 19), so build them somewhere open.

## Install

1. Install [Just Stargate Mod](https://modrinth.com/mod/jsg) 5.1.2.0 or newer for Minecraft 1.20.1 (Forge 47).
2. Put [`dist/jsginfinity-1.4.0.jar`](dist/jsginfinity-1.4.0.jar) in the same `mods` folder, on the client and on the server. Take out any older `jsginfinity` jar.

## How it works

The add-on uses the same pattern as JSG's own Movie gate:

- **Blocks:** its base, ring and chevron blocks extend JSG's Milky Way ones.
- **Block entity:** the gate's block entity extends JSG's Milky Way gate, and its merge helper names the Infinity ring and chevron blocks.
- **Renderer:** it follows JSG's Milky Way renderer step for step, binding the Infinity textures where JSG binds its own.
  - The swirl is one more see-through layer, drawn just in front of JSG's horizon once the kawoosh is over, turning with the game's clock.
  - For the iris, the Infinity texture stands in for JSG's under JSG's own key while an Infinity gate draws its iris, and JSG's is put back straight after.
- **Tags:** JSG finds gates, their parts and DHDs by block tags, and links a gate and a DHD only when each is in the other's tag. The add-on adds its blocks to the tags their Milky Way twins are in, without replacing JSG's entries.

The Infinity and orange DHDs are JSG's Milky Way DHD block entity on blocks of their own. JSG and Minecraft keep two lists by the exact block, and at startup the add-on adds its DHD blocks to both:
- **The blocks JSG's DHD block entity may stand in.** Without this, Minecraft wouldn't tick the DHDs.
- **JSG's key finders, one per DHD block.** When you press use on a DHD, JSG finds the key you're looking at from the outlines of its keys. Without this, nothing happened when you pressed a key on the add-on's DHDs (1.1.0 to 1.3.0).
  - The orange DHD uses JSG's own key outlines.
  - The Infinity DHD uses its screen's. Its keys are drawn from the same layout (`InfinityScreen`), turned and moved by the same maths JSG uses to find them, so what you see is what you press.

The add-on's renderer takes over JSG's DHD renderer and leaves every JSG DHD to JSG's own drawing:
- It draws the orange DHD by JSG's steps, with the orange textures: each key's light at the brightness JSG chose.
- It builds the Infinity DHD's console itself from boxes. The keys, the gate and the address on the screen follow JSG's state for the DHD.

`tools/make_resources.py` makes the textures, block states, models, recipes, loot tables and tags. It paints every texture from scratch. From your JSG jar it reads only the shapes and UV layouts of the Milky Way gate and DHD models, so the textures line up with them; it never reads JSG's textures. Each texel is coloured from the point of the model it lands on, and sharp edges of the model get ink lines. The Infinity DHD's symbols are the one thing drawn with JSG's own pictures, which the renderer loads from the JSG you have installed: the same pictures JSG shows on its own screens.

## Build

```
python3 tools/make_resources.py jsg-1.20.1-5.1.2.0.jar   # only after changing the look
./gradlew build
```

The jar is `build/libs/jsginfinity-1.4.0.jar`. Gradle fetches JSG from Modrinth's maven to compile against. `./gradlew runServer` and `./gradlew runClient` start Minecraft with JSG and the add-on installed.

## Tested

In Minecraft 1.20.1 with Forge 47.4.29 and JSG 5.1.2.0, in the development server and client that `./gradlew runServer` and `runClient` start.

**On the server:**
- JSG and the add-on loaded with no errors, recipes and loot tables included.
- `/jsginfinity build` built two gates, facing north and south, and both formed. JSG gave them Milky Way, Pegasus and Universe addresses, as it gives every gate, and each ring and chevron block linked to its base.
- JSG's `/jsg rig` opened an incoming wormhole on an Infinity gate. The gate dialled, opened, let JSG's travellers through and closed again by itself.

**In the client** (software rendering), joined to that server:
- The pictures above: the gate drawn with JSG's models in the Infinity colours.
- The chevrons lighting up as they lock, and the pale wormhole.
- The blocks before the gate forms, with JSG's diagram.

**The Infinity DHD (1.1.0)**, on the same server and client:
- Placed in front of an Infinity gate, it linked both ways: the DHD to the gate and the gate to the DHD. JSG's own DHD linked to an Infinity gate the same way.
- After a restart it loaded and ticked like a JSG DHD.
- In the client it drew in the Infinity colours, and a JSG DHD beside it still drew as JSG's own.
- In a player's own game, 1.1.0 showed the gate and the Infinity DHD, and the DHD's keys lit as they dialled.

**The orange DHD (1.2.0)**, on the dev server and client:
- Placed in front of an Infinity gate, it linked both ways.
- The DHDs placed before the update loaded and ticked as before.
- In the client the three DHDs drew side by side, each in its own look (picture above).
- In a player's own game, 1.2.0 with the orange DHD worked.

**The whirlpool, the iris and the buildings (1.3.0)**, on the dev server and client:
- With a wormhole open (from `/jsg rig`), the whirlpool turned over the settled horizon, and not over the kawoosh.
- With a titanium iris closed (set in the gate's data), the iris drew in the Infinity texture, and other gates kept JSG's iris.
- `/jsginfinity platform` and `/jsginfinity room` built facing south, the gates formed, and each DHD linked to its gate. JSG's `/jsg rig` then opened a wormhole on each gate, and JSG's travellers came through onto the pyramid and down the ramp.
- In a player's own game, 1.3.0 built Carter's platform and the Infinity gate room.

**The cartoon colours, the blue swirl and the screen DHD (1.4.0)**, on the dev server and client:
- Key presses, tested with real right-clicks in the client: the gate room's Infinity DHD dialled Carter's platform. Each press lit its key and added its symbol to the gate's dialled address. After the seventh symbol, the dial button opened the wormhole between the two gates, and pressing it again closed it.
- While dialling, the screen's gate lit a chevron for each symbol, and the dial button glowed once the gate opened.
- Both open gates showed the white horizon with the blue swirl, and the closed iris the pale blue spiral.
- JSG's DHD, the Infinity DHD and the orange DHD drew side by side, each in its own look.
- In a player's own game, 1.4.0's DHD keys lit up when pressed.

**On a dedicated server, with 1.0.0** (Forge 47.4.29, JSG 5.1.2.0, CC: Tweaked 1.120.2, with Stargate Journey 0.6.54, Chevron Seven and the Stargate Command Addon in the same world):
- Everything loaded together without errors from these mods.
- Two Infinity gates, each powered by a JSG creative capacitor, with an advanced computer under each base. The computers ran this repository's `sgc` library.
  - The library found the gate and read it as a JSG Milky Way gate with its 8-symbol address.
  - One gate dialled the other: the ring turned to each of the six symbols, seven chevrons locked, and the wormhole opened. The computer at the other gate saw it come in, and then saw it close when the first computer closed it.
- Breaking a base dropped an Infinity base that kept the gate's 17.8 million FE and its upgrade slots.

**Not tested yet:**
- The orange DHD's key presses. They go through the same fix as the Infinity DHD's, with JSG's own key outlines, but only the Infinity DHD was dialled in the test.
- The screen's crystal lamp. The test put the crystal in by editing the DHD's data, which doesn't reach the client, so the lamp stayed dark. Whether it lights when a crystal is put in by hand hasn't been tried.
- Crafting the blocks in survival.
- Placing the blocks by hand.
- Closing the iris from a DHD, a remote or a computer. The test closed it by setting the gate's data.
- A player breaking the base. The test broke it with `/setblock … destroy`, which never calls the code that turns the ring back into separate blocks, in JSG's own gates as well. The Infinity base inherits that code from JSG's Milky Way base unchanged.

## License

MIT, see [LICENSE](../LICENSE): the code, and the textures, which are drawn by `tools/make_resources.py`. Just Stargate Mod isn't included and keeps its own license; you need it installed.
