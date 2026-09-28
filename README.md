# lgtv-hotkeys

Ctrl+Shift+Left and Ctrl+Shift+Right cycle an LG webOS TV through connected HDMI inputs in numeric order, wrapping at either end. Carbon hotkeys need no Accessibility permission.

Requires macOS and a TV on the same LAN. Use the same Wi-Fi band if your router isolates bands.

Run `make build` to compile and run the selftest. Run `./lgtv-hotkeys daemon` to start the hotkeys.

Copy `config.example.json` to `~/.config/lgtv-hotkeys/config.json` and set `ip` to your TV address. Omit `ip` to find the TV on the first press. With no `clientKey`, press a hotkey and accept the TV pairing prompt with the LG remote. The key is saved automatically. To re-pair a rejected key, delete `clientKey` and press a hotkey again. Config saves keep only `ip` and `clientKey`.

The connection uses wss on port 3001, accepting the TV's self-signed certificate, then falls back to ws on port 3000. A paired daemon warms the connection after registering hotkeys. A failed switch retries with a fresh connection, then sweeps the subnet and saves a changed IP. The small queue cap limits key repeats.

Commands:

- `daemon`: run the hotkeys
- `next`: switch to the next connected HDMI input
- `prev`: switch to the previous connected HDMI input
- `selftest`: run local tests without contacting the TV

Run `make install-agent` to build and start the daemon at login. Logs go to `/tmp/lgtv-hotkeys.log`. Run `make uninstall-agent` to remove the agent.

MIT license. See LICENSE.
