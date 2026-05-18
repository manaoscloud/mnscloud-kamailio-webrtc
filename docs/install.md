# Installation

## Requirements

Supported operating systems:

- Debian 12
- Debian 13

The installer uses Debian official repositories for base packages, Nginx, and
rtpengine. Kamailio is installed from the official Kamailio 6.1 APT repository
for Debian `bookworm` or `trixie`, with APT pinning so Kamailio packages are not
silently mixed with older distribution packages.

APT package installation runs in non-interactive mode and keeps existing local
configuration files when Debian package prompts appear. The installer writes the
MNSCloud Kamailio configuration after package installation.

Run:

```bash
sudo bash scripts/install-kamailio-webrtc.sh
```

The installer creates and prints the node UUID before asking for the token, so
fresh nodes can be registered in MNSCloud during the installation flow.

The installer asks for:

- MNSCloud API base URL
- WebRTC edge public domain
- WebRTC node token generated in MNSCloud, when the node has already been
  registered in `VoIP > WebRTC > Server`

It generates:

```text
/etc/mnscloud/kamailio-webrtc/node.uuid
```

Register this node in MNSCloud and write the generated token to:

```text
/etc/mnscloud/kamailio-webrtc/node.token
```

When the token is provided during installation, the installer validates the node
against:

```text
POST /api/v1/webrtc/edge/bootstrap
```

The node UUID is sent in `X-WebRTC-Node-UUID`, and the token is sent as a bearer
token. If the token is not provided during installation, register the displayed
UUID in MNSCloud, rotate/generate the token in the WebRTC server screen, write it
to `node.token`, and then run the sync service.

## Synchronize Configuration

```bash
sudo bash scripts/update-kamailio-webrtc.sh
```

Or use systemd:

```bash
sudo systemctl restart mnscloud-webrtc-sync.service
```
