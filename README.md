# lgtv-hotkeys

System-wide hotkeys that drive an LG webOS TV from a Mac. Ctrl+Shift+Left and Ctrl+Shift+Right cycle the TV through its connected HDMI inputs, and Ctrl+Shift+Up wakes it with Wake-on-LAN. The hotkeys use Carbon RegisterEventHotKey, so no Accessibility permission is needed.

The daemon talks to the TV over the ssap websocket protocol: wss on port 3001 with the TV's self-signed cert accepted, falling back to ws on port 3000 for old firmware. On first use the TV shows an Allow prompt, you accept it once with the LG remote, and the client key is stored locally. If the TV's IP goes stale (routers reshuffle DHCP leases), the daemon re-discovers the TV with a unicast TCP sweep of the subnet and re-pins the IP on its own.

## Requirements

- macOS
- An LG webOS TV on the same LAN as the Mac
- The Mac and the TV on the same Wi-Fi band (some access points isolate bands from each other)

## Build

    make build

This compiles Sources/lgtv-hotkeys.swift to ./lgtv-hotkeys and runs the built-in selftest, so a broken build can never be installed.

## Config

The real config lives at ~/.config/lgtv-hotkeys/config.json and is never committed. Copy the example there and edit it:

    mkdir -p ~/.config/lgtv-hotkeys
    cp config.example.json ~/.config/lgtv-hotkeys/config.json

Keys the daemon reads:

- ip: TV IP address. Omit it or leave it empty and the daemon discovers the TV by sweeping the subnet for the webOS ports.
- clientKey: the ssap pairing key. Filled in automatically by ./lgtv-hotkeys pair, or copy the value from another already-paired LG TV tool.
- mac: TV MAC address, needed for Wake-on-LAN wake from standby. Any separator style and case works.
- audioSyncPath: optional absolute path to an lgtv-audio-sync binary. After each input switch the daemon calls it so the audio follows the keypress immediately instead of waiting for its poll. A sibling binary named lgtv-audio-sync next to this one is found without any config.

## Install as a LaunchAgent

    make install-agent

This renders launchagents/com.lgtv.hotkeys.plist.template with the absolute binary path and log path, writes it to ~/Library/LaunchAgents/com.lgtv.hotkeys.plist, and bootstraps it with launchctl. The agent starts at login and is kept alive.

    make uninstall-agent

boots the agent out and removes the plist.

## Hotkeys

- Ctrl+Shift+Right: next connected HDMI input
- Ctrl+Shift+Left: previous connected HDMI input
- Ctrl+Shift+Up: wake the TV (Wake-on-LAN plus screen on)

## Commands

The binary also works standalone:

    ./lgtv-hotkeys daemon     run the hotkey daemon (what the LaunchAgent runs)
    ./lgtv-hotkeys next       switch to the next connected HDMI input
    ./lgtv-hotkeys prev       switch to the previous connected HDMI input
    ./lgtv-hotkeys wake       wake the TV (Wake-on-LAN + screen on)
    ./lgtv-hotkeys list       show TV inputs and the current app
    ./lgtv-hotkeys pair       pair with the TV (accept the prompt with the LG remote)
    ./lgtv-hotkeys discover   sweep the subnet for webOS TVs
    ./lgtv-hotkeys status     show config and reachability
    ./lgtv-hotkeys selftest   run the pure-logic test suite

## Log

The LaunchAgent logs to /tmp/lgtv-hotkeys.log.

## License

MIT, see LICENSE.
