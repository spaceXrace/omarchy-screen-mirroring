# Screen Mirroring

An Omarchy Quattro bar widget for mirroring a Linux desktop to compatible AirPlay receivers with [doubletake](https://github.com/omarroth/doubletake).

## Features

- Screen mirroring icon in the right status-bar category.
- Receiver discovery starts when the panel opens and when **Reload** is clicked.
- One-click reconnect to the last receiver, plus an on/off control in the panel header.
- PIN and configured-password prompts for protected receivers.
- Saved extra doubletake arguments, such as `-hwaccel vaapi`.
- Receiver-specific, temporary UFW UDP rule for `60000:60010` while a stream is active.

## Install

```sh
omarchy plugin add https://github.com/spaceXrace/omarchy-screen-mirroring --enable --yes
```

Open the widget and select **Install dependencies**. It installs the AUR `doubletake` package and the GStreamer/VA-API packages through `omarchy pkg`.

## Use

1. Open the status-bar widget and click **Reload** to discover receivers.
2. Select a receiver. A graphical Polkit prompt authorizes a UFW rule restricted to that receiver IP, then starts mirroring.
3. Enter a pairing PIN or receiver password when prompted.
4. Use **Off** to end mirroring. The helper removes its tagged UFW rules after disconnecting.

The header's on/off control reconnects to the last receiver when idle. The bar icon only opens and closes the panel.

## Arguments

Arguments are passed to doubletake when its daemon starts. For example, use `-hwaccel vaapi` for VA-API encoding. The widget reserves `-daemonize`, `-socket`, and `-port-range`; those cannot be overridden.

## Notes

- The helper starts doubletake only while the panel is in use or a stream is active. A running stream keeps its daemon alive.
- Doubletake's daemon performs its own mDNS discovery while it is running. The widget does not issue discovery requests while the panel is closed.
- UFW operations use the desktop Polkit prompt rather than opening a terminal. No broad firewall rule is added: each rule is limited to the selected receiver IP and is marked with the plugin ID for safe cleanup.
- **Keep receiver ports open** retains each receiver-specific rule after its first authorization, avoiding later password prompts for that receiver. Turning it off removes all rules retained by this plugin.
- Screen capture source selection is handled by doubletake.

## Development

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
```

## License

MIT. Doubletake is a separate LGPL-3.0-or-later dependency.
