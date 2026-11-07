# StargateNetwork

Links all your Stargates together over rednet. Every gate running this program finds the others on its own. You can dial any of them from a list, see who is calling, and control gates from a pocket computer.

Written for **Stargate Journey 0.6.x** and **CC:Tweaked** on **Minecraft 1.20.1**.

## Features

- **Finds gates automatically:** every gate in the same network shows up with its live status (IDLE, DIALING, INCOMING, OUTGOING), gate type, energy and iris.
- **Remembers gates:** gates are saved to disk, so you can still dial a gate whose chunk is unloaded (it shows as OFFLINE).
- **Dial from a list:** use the arrow keys and Enter, or click an entry twice. You can also type any address and save it to the address book.
- **Caller ID:** an incoming wormhole shows which network gate is calling.
- **Auto-iris (optional):** the iris closes for every incoming wormhole and opens again only for gates from your network.
- **Remote control:** a pocket computer (or any computer without a gate) can dial, close the gate and work the iris on any gate that shares the network key.
- **Network log:** see what the other gates are doing ("Earth is dialing Abydos").
- **Works with any interface:** Milky Way gates spin the ring and lift the chevrons, and other gates dial with `engageSymbol`.
- **Any screen:** it adapts to computer, pocket computer and turtle screens, in colour or black and white.

## What you need

| Role | Setup |
|------|-------|
| Gate node | A computer touching (or wired to) a **basic, crystal or advanced crystal interface**, plus a **wireless or ender modem** |
| Remote | Any computer or pocket computer with a wireless/ender modem (an ender modem works across dimensions) |

An **advanced crystal interface** reads the gate's address automatically. With other interfaces, setup asks you to type the address in so other gates can dial you.

Iris control needs a Stargate Journey version with iris support. If the interface has no iris functions, the program skips that part.

## Install

With the HTTP API enabled:

```
wget https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/StargateNetwork/installer.lua installer
installer
```

Or copy `sgnet.lua` onto the computer by hand. It is the only file you need.

## First start

Run `sgnet`. Setup asks for:

1. **Gate name**, as other gates will see it
2. **Network name**: only gates with the same network see each other
3. **Network key**: a shared password for remote control. Leave it blank to turn remote control off.
4. Whether others with the key may control this gate
5. Auto-iris on or off (only if the gate supports an iris)
6. The gate's address, if the interface can't read it

Run `sgnet setup`, or press **S** in the program, to change these later.

## Keys

| Key | Action |
|-----|--------|
| Up / Down, PgUp / PgDn | Pick a destination |
| Enter (or click twice) | Dial it |
| M | Dial a typed address (`26-6-14-31-11-29` or `26 6 14 31 11 29`), with an option to save it |
| D | Close the gate or stop dialing |
| I | Open or close the iris |
| G | Switch which gate you control (this one, or any remote gate that allows it) |
| R | Ask every gate to report in |
| X / Delete | Remove the selected address book entry, or forget an offline gate |
| S | Setup |
| H | Help |
| Q | Quit |

In the list, `*` marks the gate you are controlling and `>` marks your selection.

## Config files

- `sgnet.cfg`: settings and the address book. Edit it by hand to add many addresses at once:

  ```lua
  book = {
    { name = "Abydos", address = { 26, 6, 14, 31, 11, 29 } },
    { name = "My Base", address = "12-5-33-27-9-2" },
  },
  ```

  Other options: `fastDial` (Milky Way through a crystal interface: skip spinning the ring), `trustNetwork` (auto-iris opens for network gates), `showNetworkLog`, `aliases` (other addresses of this gate, used to recognise callers), and `address` (force the address others should dial).

- `sgnet_dir.dat`: the saved list of network gates. Delete it to start fresh.

## Security note

Rednet is not encrypted. Anyone with a modem can listen in and copy the network key, or pretend to be a gate from your network. The key stops casual misuse, but it does not make your base safe from a determined player. Pick a key you don't use anywhere else.

## How it works

Each gate node broadcasts a small status message every 15 seconds and whenever its state changes. These go out on the rednet protocol `sgnet:<network>`. Remote commands go straight to the target computer and carry the network key. A gate counts as offline after 45 seconds of silence, but stays in the list so you can still dial it.
