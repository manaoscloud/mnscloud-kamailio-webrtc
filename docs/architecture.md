# Architecture

MNSCloud Kamailio WebRTC Edge is a public signaling and media edge for
multi-tenant WebRTC access.

The PABX remains internal. The edge receives browser WebRTC traffic and forwards
validated SIP signaling to the correct FreeSWITCH or Asterisk target.

## Identity

The canonical identity is:

```text
extension@domain
```

The extension username alone is never globally unique. Domains are part of
authentication, routing, logging, and tenant resolution.

## Control Plane

The MNSCloud API is the control plane. The edge fetches dynamic configuration
from:

```text
GET /api/v1/webrtc/edge/config
```

The response describes domains, PABX targets, RTP ranges, and edge policy.

## Data Plane

Kamailio handles signaling. rtpengine handles media.

```text
WSS -> Nginx -> Kamailio -> PABX
             -> rtpengine -> RTP/SRTP media
```

