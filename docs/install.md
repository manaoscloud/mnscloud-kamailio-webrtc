# Installation

## Requirements

Supported operating systems:

- Debian 12
- Ubuntu 22.04
- Ubuntu 24.04

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

