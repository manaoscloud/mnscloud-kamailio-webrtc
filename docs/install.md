# Installation

## Requirements

Supported operating systems:

- Debian 12
- Debian 13

The installer uses `mnscloud-runtime-kit` for shared host packages such as Nginx and Certbot, uses
Debian official repositories for base packages and rtpengine, and installs Kamailio from the
official Kamailio 6.1 APT repository for Debian `bookworm` or `trixie`, with APT pinning so
Kamailio packages are not silently mixed with older distribution packages.

APT package installation runs in non-interactive mode and keeps existing local
configuration files when Debian package prompts appear. The installer writes the
MNSCloud Kamailio configuration after package installation.

The base package set includes runtime dependencies and focused troubleshooting
tools: `dnsutils`, `iproute2`, `iputils-ping`, `netcat-openbsd`, `ngrep`,
`tcpdump`, and `traceroute`.

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

The installer also supports non-interactive parameters used by the MNSCloud App
`Generate install command` action. The generated command intentionally leaves
the WebRTC public domain interactive because the correct WSS domain can vary per
edge server:

```bash
sudo bash scripts/install-kamailio-webrtc.sh \
  --api-base https://api.example.com \
  --node-uuid 00000000-0000-0000-0000-000000000000 \
  --runtime-token '<shown-once-runtime-token>'
```

The installer asks for:

- MNSCloud API base URL, unless `--api-base` is supplied.
- WebRTC edge public domain, defaulting to `webrtc.example.com`.

Fully non-interactive automation can still pass `--public-domain` or set
`MNSCLOUD_WEBRTC_PUBLIC_DOMAIN` explicitly.

It generates:

```text
/etc/mnscloud/kamailio-webrtc/node.uuid
```

When `--node-uuid` and `--runtime-token` are supplied, the installer validates
the runtime identity with the MNSCloud API and posts bootstrap metadata to:

```text
POST /api/v1/webrtc/edge/bootstrap
```

The bootstrap payload updates the WebRTC server record with hostname, public
domain, public/private IPs, base URL, version, and last-seen information. The
update/sync script repeats this metadata sync after applying edge configuration.

The installer also renders Nginx for HTTPS/WSS on `443/tcp`. Trusted TLS
material should be installed at:

```text
/etc/mnscloud/kamailio-webrtc/tls/fullchain.pem
/etc/mnscloud/kamailio-webrtc/tls/privkey.pem
```

If those files are missing, the installer generates a temporary self-signed
certificate so Nginx can start. Browser WebRTC clients require a trusted
certificate, so replace the temporary certificate before production use.

Additional public WSS domains can be registered in MNSCloud under
`VoIP > WebRTC > Domain`. The sync service renders those domains on the same
edge server and can issue Let’s Encrypt certificates when:

- DNS `A`/`AAAA` records point to the WebRTC edge.
- `80/tcp` and `443/tcp` reach Nginx.
- Certbot is installed by the module.
- The API returns `certbotEmail`. It resolves this from WebRTC parameter
  `certbot_email`, then the tenant/user email, then `no-reply@manaos.cloud`.

For production provisioning, enroll `mnscloud-agent` first and confirm it is
online with the `webrtc.kamailio.manage` capability. WebRTC domain, certificate,
and edge sync work is then delivered as Agent jobs. The app may show only a
short-lived Agent enrollment token; the long-lived Agent runtime token is issued
directly to the server during `POST /api/v1/agent/enroll`.

Provisioning is Agent-first. The WebRTC server must be assigned to an online
`mnscloud-agent` with `webrtc.kamailio.manage`; configuration sync, domain
provisioning, and certificate work are delivered as Agent jobs and recorded in
Activity Logs.

## Synchronize Configuration

```bash
sudo bash scripts/update-kamailio-webrtc.sh
```

Or use systemd:

```bash
sudo systemctl restart mnscloud-webrtc-sync.service
```

## Validate Runtime

After install or update, validate rendered configuration and core service health:

```bash
sudo bash /opt/mnscloud/kamailio-webrtc/scripts/validate-kamailio-webrtc.sh
```
