# Installation

## Requirements

Supported operating systems:

- Debian 12
- Debian 13

The installer uses `mnscloud-runtime-kit` for shared host packages such as Nginx and upstream
Certbot Snap, and installs Kamailio from the official Kamailio 6.1 APT repository for Debian
`bookworm` or `trixie`, with APT pinning so Kamailio packages are not silently mixed with older
distribution packages. rtpengine packages and media service lifecycle are owned by
`mnscloud-media`.

APT package installation runs in non-interactive mode and keeps existing local
configuration files when Debian package prompts appear. The installer writes the
MNSCloud Kamailio configuration after package installation.

The base package set includes runtime dependencies and focused troubleshooting
tools: `dnsutils`, `iproute2`, `iputils-ping`, `netcat-openbsd`, `ngrep`,
`tcpdump`, and `traceroute`.

The installer renders Kamailio with the media control socket returned by the API
runtime config. If the API does not provide one yet, Kamailio defaults to
`udp:127.0.0.1:2223` so a colocated media runtime can work during development.

Kamailio private SIP listeners are rendered from the runtime config returned by
the API. During a first clean install, that config may not contain the node
private IP until the bootstrap callback completes; in that case the installer
uses the local IPv4 source address from the default route and only renders it
when that address is assigned to the host.

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
POST /api/v1/realtime/webrtc/edge/bootstrap
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
`Realtime > WebRTC > Domain`. The sync service renders those domains on the same
edge server and can issue Let’s Encrypt certificates when:

- DNS `A`/`AAAA` records point to the WebRTC edge.
- `80/tcp` and `443/tcp` reach Nginx.
- Certbot is installed by the module.
- The API returns `certbotEmail`. It resolves this from WebRTC parameter
  `certbot_email`, then the tenant/user email, then `no-reply@manaos.cloud`.

For production provisioning, enroll `mnscloud-agent` first and confirm it is
online with the `realtime.webrtc.manage` capability. WebRTC domain, certificate,
and edge sync work is then delivered as Agent jobs. The app may show only a
short-lived Agent enrollment token; the long-lived Agent runtime token is issued
directly to the server during `POST /api/v1/agent/enroll`.

Provisioning is Agent-first. The WebRTC server must be assigned to an online
`mnscloud-agent` with `realtime.webrtc.manage`; configuration sync, domain
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

After install or update, validate rendered configuration and core signaling service health:

```bash
sudo bash /opt/mnscloud/kamailio-webrtc/scripts/validate-kamailio-webrtc.sh
```
