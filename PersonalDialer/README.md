# Personal Dialer

An address book you can dial from. Save gates with a name and a note, find them with a live search, and dial with a double-click. The wormhole closes behind you after you step through.

Written for Stargate Journey on Minecraft 1.20.1 with CC: Tweaked.

![Personal Dialer screens](../imgs/PersonalDialer.png)

*Top: dialing with the Milky Way theme, and an open wormhole with the Legacy Hybrid theme. Bottom: adding an address, and the gate info panel. These screens were rendered from a headless CC: Tweaked test harness, not captured in-game.*

## Features

- **Address book**: name, address and a free-text note (galaxy, dimension, owner...) for every gate, saved in `dialer_addresses.db`.
- **Live search** by name, address or note.
- **Add, edit, remove and reorder** entries with the mouse or the keyboard.
- **Dials every gate type** through any interface:
  - **Milky Way:** rotates the ring, alternating direction like the show, then opens and closes each chevron. Fast mode engages symbols directly when the interface supports it.
  - **Pegasus, Universe, Tollan and Classic:** engages symbols directly.
- **Chevron bar**: shows the address being dialed and which chevrons are locked, plus the gate state (IDLE, DIALING, OPEN or INCOMING).
- **Auto-close**: closes your outgoing wormhole a few seconds after someone steps through, or after 30 s if nobody uses it. The countdown is shown on the OPEN badge.
- **Incoming wormholes**: shows the caller by name if the address is in your book. The *Add* dialog is pre-filled with the caller's address.
- **Last result marker**: green after a successful dial, red after a failed one.
- **Gate info panel**: gate type, local address, energy, iris open/close, colour theme and dial mode.
- **Colour themes**: Auto (follows the gate type), Milky Way, Pegasus, Universe, Tollan, Classic and Legacy Hybrid (amber, red and purple chevrons with a blue master chevron).
- **Monitor mode**: runs on an advanced monitor. Touch to use it, or type on the computer.
- **Cartouche import**: on first start, imports `1_cartouche.lua` from [Stargate Monitor](../StargateMonitor/) if it is in the same folder.

## Requirements

- Minecraft 1.20.1, Stargate Journey 0.6.x, CC: Tweaked
- A basic, crystal or advanced crystal interface next to the computer or on a wired modem network. The local address in the title bar needs an advanced crystal interface.
- An advanced computer is recommended for mouse support and colour. Keyboard controls also work on a basic computer.

## Installation

With HTTP enabled in the CC: Tweaked config:

```
wget https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/PersonalDialer/dialer.lua dialer.lua
```

Then run it:

```
dialer            -- on the computer screen
dialer monitor    -- on an attached advanced monitor
```

To start it automatically, create `startup.lua` containing `shell.run("dialer")`.

## Controls

| Mouse | Keyboard | Action |
|---|---|---|
| click an address | Up / Down, Page Up / Page Down | select |
| double-click, `DIAL` | Enter | dial the selected address |
| `[+]` | Ctrl+N or Insert | add an address |
| `[-]` | Ctrl+D or Delete | remove the selected address |
| `[E]` | Ctrl+E | edit the selected address |
| ▲ ▼ next to an address | Shift+Up / Shift+Down | move the address |
| `[i]` | Ctrl+I | gate info, iris, theme, dial mode |
| `[?]` | Ctrl+H | help |
| `CLOSE` | Ctrl+X | close the gate or abort dialing |
| `[x] Auto-close` | Ctrl+A | toggle auto-close |
| `QUIT` | Ctrl+Q or Ctrl+T | exit |

Typing anywhere on the main screen goes into the search box. Addresses can be typed as `26 6 14 31 11 29`, `26,6,14,31,11,29` or `-26-6-14-31-11-29-`. The point of origin is added automatically when dialing.

## Configuration

The `CONFIG` table at the top of `dialer.lua` holds:

- `dataFile`: where the address book is stored
- `interfaceName`: which interface to use if the computer can reach several
- `symbolDelay`, `chevronDelay`: dialing speed
- `stepTimeout`, `connectTimeout`: when to give up on a stuck dial
- `autoCloseDelay`, `autoCloseIdle`: auto-close timings
- `pollInterval`: how often the gate state is re-read
- `monitorScale`: text scale in monitor mode

## Notes

- The three starting addresses (Abydos, Chulak and Lantea) are the defaults from the Stargate Journey examples. Your world may use different ones.
- Only one dial runs at a time. Dialing is refused while a wormhole is active or another gate is dialing in.
- Gate state is read from interface events and also re-checked every second, so a missed event does not leave the screen stuck.
