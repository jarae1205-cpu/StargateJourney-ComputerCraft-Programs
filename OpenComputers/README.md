# gatedial for OpenComputers

A stargate dialing computer for **OpenComputers** (OpenOS), for the gate mods that talk to OpenComputers:

- **SGCraft**: Greg Ewing's original (1.7.10) and SGCraft 2.x (1.12.2)
- **Just Stargate Mod** for Minecraft 1.12.2 (JSG), Milky Way, Pegasus and Universe gates
- **LanteaCraft** 0.2.5+ for Minecraft 1.21.1, with an OpenComputers port for 1.21.1 (see the note under [Connect the gate](#connect-the-gate))

It is the OpenComputers version of the [Personal Dialer](../PersonalDialer/) and the [Gate Room](../StargateCommand/). It keeps the same address book, trusted iris codes and gate log, so a book written on one computer works on the other. It does not need the Auspex Gate Systems programs.

On a tier 2 or tier 3 screen, gatedial 2.0 opens on the **console**: a control screen with panels, made for a gate room. It has the address book, the selected address with big Dial, Close Gate and Iris buttons, switches, the GDO (iris codes in and out) and the gate with a box for each chevron.

![The gatedial console on a tier 3 screen](../imgs/OpenComputersConsole.png)

![The console while dialing, with the iris shut on an unknown code, and on a tier 2 screen](../imgs/OpenComputersConsoleStates.png)

*The console on a JSG 1.12.2 Milky Way gate. Top: a tier 3 screen (160x50) with the wormhole open to Abydos and the iris code sent. Bottom, left to right: dialing Abydos; another gate dialed in, the automatic iris closed, and code 9999 was rejected; a tier 2 screen (80x25) dialing Chulak. These screens were rendered from a headless OpenOS test harness with a simulated gate.*

![The console in a Minecraft 1.12.2 world](../imgs/OpenComputersConsoleInGame.jpg)

*Screenshots from a Minecraft 1.12.2 game with OpenComputers 1.8.10 and Just Stargate Mod 4.11.2.8. Top: gate A with a wormhole open, and its computer's 3x2 tier 3 screen showing the console. Bottom left: that screen opened by the player, with the wormhole open to gate B and code 1234 sent. Bottom right: gate B's tier 2 screen opened during the same call. B's automatic iris closed as the call came in, then the code was accepted and the iris opened.*

The gatedial 1.0 screen is still there: set `screen = "classic"` (see [Settings](#settings)).

![gatedial's classic screen](../imgs/OpenComputers.png)

*Left: dialing Abydos on an SGCraft gate, with a tier 3 screen and graphics card (160x50). Right: a JSG 1.12.2 gate on a tier 2 screen (80x25), with the wormhole open and the iris code sent, then a player coming through an incoming wormhole. These screens were rendered from a headless OpenOS test harness with simulated gates, not captured in-game.*

![gatedial in a Minecraft 1.12.2 world](../imgs/OpenComputersInGame.jpg)

*In a Minecraft 1.12.2 world with OpenComputers 1.8.10 and Just Stargate Mod 4.11.2.8. Top left: the installer, downloaded with `wget` on an in-game computer. Top right: gatedial has dialed the other gate and sent its iris code. Bottom left: the computer at the other gate as that call comes in; the code 1234 is accepted. Bottom right: the gate with its wormhole open.*

![The gate picture and the iris on a tier 3 screen](../imgs/OpenComputersIris.jpg)

*A tier 3 screen in the same world, cabled to a JSG gate with a creative iris set to OC mode. Left: the gate picture beside the address book. Middle: the iris closed with the I key. Right: another gate dials in and sends a trusted code, and gatedial opens the iris by itself.*

![gatedial on SGCraft in a Minecraft 1.7.10 world](../imgs/OpenComputersSGCraft.jpg)

*SGCraft 1.13.3 and OpenComputers 1.8.10 in a Minecraft 1.7.10 world. Top left: one computer dials the other gate and sends the code 4321; the other side answers that it was accepted. Top right: at the other gate the iris was shut, so gatedial opens it for the trusted code. Bottom left: the same call with an unknown code; the iris stays shut. Bottom right: that gate with its iris closed over the wormhole.*

## Install

You need an internet card. In the OpenOS shell:

```
wget -f https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/OpenComputers/install.lua /tmp/install.lua
/tmp/install.lua
```

This puts `gatedial` and `idc` in `/home/bin` and the `sgc` library in `/home/lib/sgc`. Run the installer again to update; it downloads every file before it changes anything. Your address book, iris codes and gate log stay as they are. Then `reboot`: OpenOS keeps the libraries it has loaded in memory, so until a reboot the computer keeps using the old ones.

## Connect the gate

- **SGCraft**: place SGCraft's OpenComputers interface block directly under the gate's base and connect it to the computer with cable. It shows up as a `stargate` component.
- **JSG 1.12.2**: connect the gate's base block to the computer with cable. It is a `stargate` component too. To open and close the iris from the computer, set the iris mode to OC in the gate's GUI.
- **LanteaCraft**: connect the gate's base block to the computer with cable. gatedial handles LanteaCraft the same way as the ComputerCraft programs do; see the [LanteaCraft notes](../StargateCommand/README.md#lanteacraft-notes). But LanteaCraft 0.2.5 can't load alongside OpenComputers: Modernized 1.10.0 to 1.10.7, the OpenComputers port for 1.21.1: the game stops at startup with "Please register all drivers in the init phase". LanteaCraft adds its OpenComputers driver after OpenComputers has closed its driver list, so this needs a fix in LanteaCraft. Until then, use the ComputerCraft programs with LanteaCraft. gatedial's LanteaCraft support has only been tested against a simulated gate.

**Minecraft 1.20.1** has no stargate mod with its own OpenComputers support, but there is an unofficial OpenComputers port, OpenComputers Community Edition. Its Adapter block can show a ComputerCraft peripheral as an OpenComputers component. That isn't enough for gatedial. In a 1.20.1 game (Forge 47.4.29, OpenComputers CE 1.9.1-snapshot-3, CC: Tweaked 1.122.0, Stargate Journey 0.6.54), an Adapter next to a crystal interface gave a `crystal_interface` component with only the interface's 38 extra methods, such as `engageSymbol` and `getDialedAddress`. It didn't have the basic methods every interface has (`getStargateType`, `isStargateConnected`, `getStargateEnergy`, `disconnectStargate`), so gatedial could neither read the gate's state nor close it. On 1.20.1, use the ComputerCraft programs: the [Gate Room](../StargateCommand/) or the [Personal Dialer](../PersonalDialer/).

JSG closes a wormhole by itself when no player has been nearby for 5 seconds ("Autoclose" in JSG's `stargates.cfg`). gatedial logs that as a close with the reason Autoclose. Raise the time or turn it off in that config if your computers should keep wormholes open on their own.

Then run `gatedial`. Run `components` in the shell if the gate is not found.

## Screen

A tier 2 screen and graphics card is enough. gatedial uses the largest resolution the graphics card and screen allow.

The console needs more memory than the classic screen. In the game it used about 0.9 MB on a tier 3 screen and 0.5 MB on a tier 2 screen, OpenOS included. Two tier 3 memory sticks (1.5 MB) are enough for either. With less memory, use the classic screen.

**The console** (tier 2 or tier 3):

- **Header**: the logo, the gate's type and local address, and badges for the gate status (idle, dialing, wormhole open, incoming; it flashes while another gate dials in), the iris and the gate's energy. On tier 3 it also names the gate on the other side.
- **Address book**: tap an address to select it, tap it again to dial. `IDC` marks addresses with an iris code to send. New, Edit, Delete and Log buttons sit under the list.
- **Selected**: the name, address and iris code of the selected address, then the big buttons: **Dial** (Abort while dialing), **Close Gate**, and **Open Iris** or **Close Iris**.
- **Switches**: automatic iris, iris code check and alarm, which you turn on and off by tapping them. The console remembers them.
- **GDO**: the last iris code that came in and whether it was accepted, the last code you sent and the answer, and how many codes are trusted.
- **The gate** (tier 3): the gate picture, with its chevrons lighting as they lock, the wormhole and the iris. Beside it is a box for each chevron with its symbol, and under it the wormhole's time and a bar of locked chevrons. On tier 2 the chevrons are a list.

Tapping the iris badge in the header opens or closes the iris too. The gate log opens over the address book; Back returns to it.

**The classic screen** (`screen = "classic"`, and on a tier 1 screen): the address book as a list, with the chevrons and the gate state under it. With tier 3 it also draws the gate beside the list.

## Keys

| Key | Does |
| --- | --- |
| Up / Down | pick an address |
| Enter | dial it |
| X | close the wormhole, or stop dialing |
| I | open or close the iris |
| A | automatic iris on or off |
| N / E / D | new address, edit, delete |
| L | the gate log |
| Q | quit |

X, I and A also work while the gate log is open.

On a touch screen, tap an address to pick it and tap it again to dial. The buttons do the same as the keys. New and Edit ask their questions on the computer's keyboard.

New and edit ask for a name, an address and the iris code to send when you dial it. When you edit, each question shows the current value in [brackets]: press Enter to keep it, or type `-` to clear it. Addresses are typed the way the gate shows them: SGCraft letters such as `WLDQ-DQB-MT`, or JSG symbol names separated by commas such as `Aquila, Cetus, Gemini, Leo, Scorpius, Orion`. An entry with the wrong kind of address for the gate is shown but not dialed.

JSG dials a gate in another galaxy with 8 chevrons, for example from a Pegasus gate to a Milky Way gate. Its address then needs seven symbols, in the dialing gate's symbols. The seventh symbol is in the full address on the other gate's address page. With only six, JSG finds no gate, and gatedial says so with a reminder about the seventh symbol.

## Iris codes

Iris codes work the same as in the [Gate Room](../StargateCommand/README.md#iris-codes-and-the-gate-log):

- When you dial an entry that has an iris code, gatedial sends it as soon as the wormhole opens.
- When another gate dials in and sends a code, gatedial opens the iris if the code is trusted and answers "accepted". An unknown code gets "rejected", and the iris stays shut.
- Trust codes with `idc add 1234 SG-1`. `idc` lists them, `idc remove 1234` stops trusting one and `idc log` prints the gate log.

With SGCraft the codes go as gate messages, the same as from the ComputerCraft programs. JSG 1.12.2 has its own iris code system (the GDO), so gatedial uses that: the code arrives as JSG's `received_code` signal and the answer goes to the traveller's GDO.

Turn on **Automatic iris** on the console (or press A) to close the iris whenever another gate dials in. The GDO panel shows the last code in each direction.

## Shared files

| File | What |
| --- | --- |
| `/home/dialer_addresses.db` | the address book |
| `/home/iris_codes.db` | trusted iris codes |
| `/home/gate_log.db` | the gate log |

These are the same files the ComputerCraft programs keep at the root of a computer, in the same format. Copy them across to move an address book between the two.

## Settings

At the top of `gatedial.lua`:

- `screen`: `"console"` (the default) or `"classic"` for the gatedial 1.0 screen
- `logo`: the big letters at the top of the console, `"SGC"` by default. Letters, digits, `-` and spaces; a name too long for the big letters is written in plain text
- `irisCodes`: check iris codes from the gate that dialed in (on by default)
- `autoIris`: close the iris when another gate dials in (off by default)
- `alarm`: beep while another gate is dialing in
- `gatePicture`: draw the gate on a tier 3 screen
- `pollInterval`: seconds between gate checks

`irisCodes`, `autoIris` and `alarm` are where the console's switches start. Once you flip a switch on the console (or press A), gatedial keeps that choice in the address book's settings, and it wins over the value here.

## Tested

**The console (gatedial 2.0), in a Minecraft 1.12.2 world** (Forge 14.23.5.2860) with OpenComputers 1.8.10 and Just Stargate Mod 4.11.2.8:

- **The setup.** Two JSG Milky Way gates were spawned with JSG's own `structurespawn` command, each with a creative iris in OC mode. Each gate was cabled to a creative computer case running OpenOS from its hard disk:
  - computer A, with a 3x2 tier 3 screen (160x50);
  - computer B, with a tier 2 screen (80x25).
- **How it was driven.** A small test program on each computer ran gatedial. For most of the scenarios it sent key presses and screen taps as signals (`computer.pushSignal`, the same signals a keyboard and screen send) and read the screen back from the graphics card. A player client was joined to the world. JSG's autoclose was off, and OpenComputers' power use was turned off.
- **With the player's keyboard and mouse.** The player opened computer A's screen. Then, with real input:
  - the Down key moved the selection, and A switched the automatic iris off;
  - clicking the switch turned it on again, and clicking an address selected it;
  - clicking NEW and typing a name, an address and an iris code added the address to the book;
  - Up and Enter dialed gate B;
  - clicking CLOSE GATE closed the wormhole, and LOG and BACK opened and closed the gate log.
- **What worked.** The console drew on both screens, with the gate picture, the chevron boxes and the energy bar on tier 3.
  - A dialed B: the chevrons lit one by one, and the wormhole opened. A sent code 1234 through JSG's GDO.
  - B's automatic iris closed as the call came in. B accepted the code (`IN 1234 accepted (SG-1)`) and opened its iris.
  - Tapping the Automatic iris switch on A turned it on, and tapping DIAL on B dialed A. A's iris closed, then code 4321 was accepted and the iris opened.
  - B's iris code was changed to 9999 by typing at the Edit prompts. A rejected it, and the iris stayed shut.
  - Closing the wormhole worked from either computer, and the gate log showed the calls and the codes.
- **What the test found, now fixed.**
  - An open outgoing wormhole showed "REMOTE unknown gate". JSG 1.12.2 reads idle for a moment before the wormhole opens, which cleared the address being dialed. A's console now shows `REMOTE Gate B` and "Wormhole open to Gate B".
  - On tier 2, the status badge cut "INCOMING WORMHOLE" short and the local address ended in "...". They now read INCOMING and `Tau-Leo-Sco-Scu-Ser-Tri`.
  - The screen buffer used too much memory. It now takes about 400 KB less on tier 3.
- **A Pegasus gate.** A third JSG gate, a Pegasus gate, got its own computer, C, on a 3x2 tier 3 screen.
  - The console drew in the Pegasus look: a blue logo, gate and chevrons, and the address in Pegasus symbols.
  - Gate B's Pegasus address with six symbols failed. JSG answered `address_malformed`, because a call between galaxies takes 8 chevrons.
  - gatedial used to say only "Stargate failed to open". It now passes on JSG's reason ("No stargate at that address"), with the reminder about the seventh symbol.
  - The address was then changed to seven symbols at the Edit prompts. C dialed 8 chevrons and the wormhole opened. B's automatic iris closed, code 1234 was accepted, and B's console showed the call's 8 chevrons.
- **Not tried in the game.** The console on a JSG Universe gate, and on SGCraft and LanteaCraft gates. gatedial 1.0's gate code for SGCraft and LanteaCraft is unchanged.

**In a Minecraft 1.12.2 world** (Forge 14.23.5.2860) with OpenComputers 1.8.10 and Just Stargate Mod 4.11.2.8. Computers were cabled to the bases of two JSG Milky Way gates:

- The installer, typed into OpenOS on a computer with an internet card, downloaded every file from GitHub.
- gatedial found the gate and showed its address, state and energy. It dialed the other gate one symbol at a time; the wormhole opened and the iris code was sent.
- At the other gate, gatedial showed the incoming wormhole. The code arrived through JSG's GDO and was accepted, after `idc add 1234 SG-1`.
- Closing worked from either computer, and both gate logs recorded the calls.
- On a tier 3 screen the gate picture showed the chevrons locking, the wormhole and the iris.
- With a creative iris in OC mode, the I key closed and opened it. When a trusted code came in while it was shut, gatedial opened it.
- The test found two bugs, both fixed. JSG gives `dialedAddress` as a string, and a gate stays busy for a moment after each chevron locks. Before the fixes, every dial failed with "Chevron 1 did not lock".

**In a Minecraft 1.7.10 world** (Forge 10.13.4.1614) with SGCraft 1.13.3 and OpenComputers 1.8.10. Two gates each had an OpenComputers interface under the base, cabled to a computer with a tier 2 screen:

- The installer worked, and gatedial found each gate by its SGCraft address.
- It dialed the other gate's nine symbols, the wormhole opened and the iris code went across as a gate message.
- The other computer accepted the code and answered, and the dialing side showed "Iris code accepted".
- With an iris upgrade on the gate, the I key closed the iris. A trusted code opened it; an unknown code was rejected and the iris stayed shut, and both sides said so.
- Closing worked from the receiving side, and the gate log recorded the call, the code and the close.
- The test found three bugs, all fixed:
  - gatedial showed a tenth chevron on SGCraft gates.
  - Editing an entry blanked the fields you didn't retype. Now each question shows the current value.
  - X and I did nothing while the gate log was open.

**In a Minecraft 1.12.2 world** with SGCraft 2.3.0 and OpenComputers 1.8.10. Two gates were built with SGCraft's test spawner, each with an OpenComputers interface under its base, cabled to a computer:

- gatedial found each gate by its address, `H999-OVA-IA` and `K448-MUB-SH`.
- It dialed the other gate's nine symbols, and the iris code was sent and accepted.
- At the other gate, the incoming wormhole was recognised from the dialing direction. SGCraft 2.3 sends no `sgDialIn`.
- Closing worked from the receiving side, and the gate log recorded the call, the code and the close.
- SGCraft 2.3 turns its ring to every symbol, so this dial took about 50 seconds. gatedial gave the whole dial 60 seconds, so a slower gate or a longer trip would have given up halfway. The limit is now 60 seconds per chevron.

![gatedial on SGCraft 2.3.0](../imgs/OpenComputersSGCraft2.jpg)

*SGCraft 2.3.0 in a Minecraft 1.12.2 world. Left: the dialing computer, with all nine chevrons locked, the wormhole open and the code accepted. Right: the computer at the other gate, with the incoming wormhole and the code it accepted.*

Please open an issue if a gate behaves differently.
