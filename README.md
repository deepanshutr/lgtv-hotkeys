# lgtv-hotkeys

Ctrl+Shift+Left and Ctrl+Shift+Right cycle an LG webOS TV through connected HDMI inputs in numeric order, wrapping at either end. Ctrl+Shift+Up powers the TV on with Wake-on-LAN. Ctrl+Shift+Down powers it off. Carbon hotkeys need no Accessibility permission.

Requires macOS and a TV on the same LAN. Use the same Wi-Fi band if your router isolates bands.

Run `make build` to compile and run the selftest. Run `./lgtv-hotkeys daemon` to start the hotkeys.

Copy `config.example.json` to `~/.config/lgtv-hotkeys/config.json` and set `ip` to your TV address. Omit `ip` to find the TV on the first switch or power-off. With no `clientKey`, press an input hotkey and accept the TV pairing prompt with the LG remote. The key is saved automatically. To re-pair a rejected key, delete `clientKey` and press an input hotkey again. Set `mac` to the TV MAC address and enable "Turn on via Wi-Fi" on the TV for power-on. Without `mac`, power-on only logs that it is missing. Config saves keep `ip`, `clientKey` and `mac`.

The connection uses wss on port 3001, accepting the TV's self-signed certificate, then falls back to ws on port 3000. A paired daemon warms the connection after registering hotkeys. A failed switch or power-off retries with a fresh connection, then sweeps the subnet and saves a changed IP. The small queue cap limits key repeats. Power-on sends immediately without waiting for queued work. Hotkey completion logs include elapsed milliseconds from the keypress.

Commands:

- `daemon`: run the hotkeys
- `next`: switch to the next connected HDMI input
- `prev`: switch to the previous connected HDMI input
- `on`: power the TV on with Wake-on-LAN
- `off`: power the TV off
- `selftest`: run local tests without contacting the TV

Run `make install-agent` to build and start the daemon at login. Logs go to `/tmp/lgtv-hotkeys.log`. Run `make uninstall-agent` to remove the agent.

MIT license. See LICENSE.
