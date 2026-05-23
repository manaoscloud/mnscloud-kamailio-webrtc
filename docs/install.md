# Installation

## Requirements

Supported operating systems:

- Debian 12
- Debian 13

The installer configures the official stable nginx.org repository for Nginx, uses Debian official
repositories for base packages and rtpengine, and installs Kamailio from the official Kamailio 6.1
APT repository for Debian `bookworm` or `trixie`, with APT pinning so Kamailio packages are not
silently mixed with older distribution packages.

APT package installation runs in non-interactive mode and keeps existing local
configuration files when Debian package prompts appear. The installer writes the
MNSCloud Kamailio configuration after package installation.

Before installing rtpengine, the installer attempts to install the matching
`linux-headers-$(uname -r)` package so the rtpengine DKMS kernel module can be
built when the provider publishes compatible headers. If the matching package is
not available, installation continues and rtpengine runs in userspace mode.

The installer derives the rtpengine media interface from local routing and the
WebRTC edge public domain. If the node has a private IPv4 address and the public
domain resolves to a different IPv4 address, rtpengine is configured with the
official `local!advertised` syntax. If the node also has a routed IPv6 address,
it is added to the same `interface` line. Example:

```ini
interface=10.0.0.10!203.0.113.10;2001:db8::10
```

If no routable local address can be detected, the installer falls back to
`interface=any`, which lets rtpengine select non-loopback local addresses.

Run:

```bash
sudo bash scripts/install-kamailio-webrtc.sh
```

The installer creates and prints the node UUID before asking for the token, so
fresh nodes can be registered in MNSCloud during the installation flow.

The installer asks for:

- MNSCloud API base URL
- WebRTC edge public domain
- WebRTC node token generated in MNSCloud after the node has been registered in
  `VoIP > WebRTC > Server` with engine `kamailio`

It generates:

```text
/etc/mnscloud/kamailio-webrtc/node.uuid
```

The installer also renders Nginx for HTTPS/WSS on `443/tcp`. Trusted TLS
material should be installed at:

```text
/etc/mnscloud/kamailio-webrtc/tls/fullchain.pem
/etc/mnscloud/kamailio-webrtc/tls/privkey.pem
```

If those files are missing, the installer generates a temporary self-signed
certificate so Nginx can start. Browser WebRTC clients require a trusted
certificate, so replace the temporary certificate before production use.

Register this node in MNSCloud and write the generated token to:

```text
/etc/mnscloud/kamailio-webrtc/node.token
```

When the token is provided during installation, the installer validates the node
against:

```text
POST /api/v1/webrtc/edge/validate
POST /api/v1/webrtc/edge/bootstrap
```

The node UUID is sent in `X-WebRTC-Node-UUID`, and the token is sent as a bearer
token. The installer validates that the UUID is registered in MNSCloud with
engine `kamailio` and that the token is valid before installing Kamailio and
rtpengine. If validation fails, the installer stops.

## Synchronize Configuration

```bash
sudo bash scripts/update-kamailio-webrtc.sh
```

Or use systemd:

```bash
sudo systemctl restart mnscloud-webrtc-sync.service
```
