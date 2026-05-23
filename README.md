# MNSCloud Kamailio WebRTC Edge

MNSCloud Kamailio WebRTC Edge is a public, standalone WebRTC SBC edge for
MNSCloud. It provides secure multi-tenant SIP over WebSocket access for existing
PABX extensions using the canonical identity:

```text
extension@domain
```

The edge is designed for customers who already use FreeSWITCH or Asterisk PABX
servers and want to enable selected extensions for browser, mobile, or web app
WebRTC registration without exposing the PABX directly to the public internet.

## Architecture

```text
Browser / Mobile App / Web App
        |
        | HTTPS / WSS 443
        |
Local Nginx
        |
        | WebSocket proxy
        |
Kamailio WebRTC Edge
        |
        | rtpengine control
        |
rtpengine
        |
        | SIP / RTP internal network
        |
FreeSWITCH / Asterisk PABX
```

## Components

- **Nginx** terminates TLS and proxies WSS traffic to Kamailio.
- **Kamailio** handles SIP signaling, tenant/domain routing, WebRTC headers, and
  rtpengine integration.
- **rtpengine** anchors and bridges media between browser WebRTC
  ICE/DTLS-SRTP and traditional PABX RTP/SRTP.
- **MNSCloud API** is the control plane and provides dynamic edge configuration
  through `GET /api/v1/webrtc/edge/config`.
- **MNSCloud Agent** can optionally apply domain changes immediately through a
  typed `webrtc.edge.sync` job while the local timer remains the reconciliation
  fallback.
- **MNSCloud Cyber Security** is applied separately through the MNSCloud Agent.

## Contract

- Product/runtime: `mnscloud-kamailio-webrtc`
- Project directory: `/opt/mnscloud/mnscloud-kamailio-webrtc`
- Runtime install path: `/opt/mnscloud/kamailio-webrtc`
- Installer: `scripts/install-kamailio-webrtc.sh`
- Update command: `scripts/update-kamailio-webrtc.sh`
- Sync service: `mnscloud-webrtc-sync.service`
- Sync timer: `mnscloud-webrtc-sync.timer`
- Optional Agent capability: `webrtc.kamailio.manage`
- Optional Agent command: `webrtc.edge.sync`
- Core services: `nginx.service`, `kamailio.service`, `rtpengine.service`
- Configuration directory: `/etc/mnscloud/kamailio-webrtc`
- State directory: `/var/lib/mnscloud/kamailio-webrtc`
- Log directory: `/var/log/mnscloud/kamailio-webrtc`
- Node UUID: `/etc/mnscloud/kamailio-webrtc/node.uuid`
- Node token: `/etc/mnscloud/kamailio-webrtc/node.token`
- TLS certificate: `/etc/mnscloud/kamailio-webrtc/tls/fullchain.pem`
- TLS private key: `/etc/mnscloud/kamailio-webrtc/tls/privkey.pem`
- Domain TLS directory: `/etc/mnscloud/kamailio-webrtc/tls/domains/<domain>/`
- Nginx config: `/etc/nginx/conf.d/mnscloud-webrtc.conf`
- Kamailio config: `/etc/kamailio/kamailio.cfg`
- Generated PABX routes: `/etc/kamailio/mnscloud/mnscloud-pabx-routes.cfg`
- rtpengine config: `/etc/rtpengine/rtpengine.conf`
- Edge config endpoint: `/api/v1/webrtc/edge/config`
- Public WSS port: `443/tcp`
- Public RTP range: `30000-40000/udp`

## Install

Supported operating systems:

- Debian 12
- Debian 13

The installer configures the official stable nginx.org repository for Nginx, uses Debian official
repositories for rtpengine, and uses the official Kamailio 6.1 repository for Kamailio packages.

Install GitHub CLI if needed:
[cli/cli installation](https://github.com/cli/cli#installation).

Authenticate GitHub CLI:

```bash
gh auth login
```

Clone the private repository and install:

```bash
sudo install -d -m 0755 /opt/mnscloud
cd /opt/mnscloud
gh repo clone manaoscloud/mnscloud-kamailio-webrtc
cd /opt/mnscloud/mnscloud-kamailio-webrtc
sudo bash scripts/install-kamailio-webrtc.sh
```

The installer creates a node UUID and stores local configuration under:

```text
/etc/mnscloud/kamailio-webrtc/
```

Register the node in MNSCloud, place the generated node token in:

```text
/etc/mnscloud/kamailio-webrtc/node.token
```

The installer requires the generated token during installation and validates
that the node UUID is registered in MNSCloud with engine `kamailio` before
installing Kamailio and rtpengine. If validation fails, the installer stops.

Nginx publishes WebRTC traffic on `443/tcp` and proxies `/ws` to the local
Kamailio WebSocket listener. If no certificate exists under
`/etc/mnscloud/kamailio-webrtc/tls/`, the installer creates a temporary
self-signed certificate so the service can start. Replace it with a trusted
certificate before using browser or mobile clients in production.

One edge server can publish multiple partner or tenant WSS domains. Register
those domains in MNSCloud as WebRTC domains for the selected server; the sync
service renders SNI-based Nginx blocks and manages per-domain certificate paths.
For automatic Let’s Encrypt issuance, make sure the domain DNS points to the
edge and configure the WebRTC parameter `certbot_email`.

After installation, configuration can be synchronized with:

```bash
sudo systemctl restart mnscloud-webrtc-sync.service
sudo systemctl status kamailio rtpengine nginx --no-pager
```

## PABX Routing

The edge does not route SIP traffic by extension username alone. The control
plane sends a domain-based `pabxTargets` list in the runtime config response,
and the sync command renders Kamailio routes in:

```text
/etc/kamailio/mnscloud/mnscloud-pabx-routes.cfg
```

Each route maps the request domain to one internal PABX SIP target:

```text
extension@pbx.example.com -> sip:10.0.0.20:5060;transport=udp
```

If no target exists for a domain, Kamailio returns `404 No PABX target`. This is
intentional: the edge must fail closed instead of relaying traffic to a stale or
looping destination.

## Public Ports

Recommended public exposure:

```text
443/tcp                 WebRTC WSS through Nginx
30000-40000/udp         RTP media range, configurable
```

Do not expose these publicly by default:

```text
5060/udp
5061/tcp
rtpengine control port
Kamailio admin ports
```

Firewall and security enforcement should be applied through the MNSCloud Cyber
Security module using the WebRTC Edge profile.

## Documentation

- [Architecture](docs/architecture.md)
- [Installation](docs/install.md)
- [Configuration](docs/configuration.md)
- [Security](docs/security.md)
- [Scaling](docs/scaling.md)
- [Troubleshooting](docs/troubleshooting.md)
