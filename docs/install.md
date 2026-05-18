# Installation

## Requirements

Supported operating systems:

- Debian 12
- Debian 13

The installer uses Debian official repositories for base packages, Nginx, and
rtpengine. Kamailio is installed from the official Kamailio 6.1 APT repository
for Debian `bookworm` or `trixie`, with APT pinning so Kamailio packages are not
silently mixed with older distribution packages.

Run:

```bash
sudo bash scripts/install-kamailio-webrtc.sh
```

The installer asks for:

- MNSCloud API base URL
- WebRTC edge public domain

It generates:

```text
/etc/mnscloud/kamailio-webrtc/node.uuid
```

Register this node in MNSCloud and write the generated token to:

```text
/etc/mnscloud/kamailio-webrtc/node.token
```

## Synchronize Configuration

```bash
sudo bash scripts/update-kamailio-webrtc.sh
```

Or use systemd:

```bash
sudo systemctl restart mnscloud-webrtc-sync.service
```
