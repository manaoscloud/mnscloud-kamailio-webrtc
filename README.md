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
- **MNSCloud Cyber Security** is applied separately through the MNSCloud Agent.

## Install

Supported operating systems:

- Debian 12
- Debian 13

The installer uses Debian official repositories for Nginx and rtpengine, and
the official Kamailio 6.1 repository for Kamailio packages.

```bash
git clone https://github.com/manaoscloud/mnscloud-kamailio-webrtc.git
cd mnscloud-kamailio-webrtc
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

If the token is provided during installation, the installer validates the node
against the MNSCloud API automatically. If the token is added later, run:

```bash
sudo systemctl restart mnscloud-webrtc-sync.service
sudo systemctl status kamailio rtpengine nginx --no-pager
```

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
