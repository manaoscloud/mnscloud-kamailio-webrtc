# Architecture

MNSCloud Kamailio WebRTC Edge is a public signaling edge for multi-tenant
WebRTC access.

The PABX remains internal. The edge receives browser WebRTC traffic and forwards
validated SIP signaling to the correct FreeSWITCH or Asterisk target.

This module is separate from the `mnscloud-nginx` HTTP application edge.
`mnscloud-nginx` may publish browser UI clients and `/api/v1`, while this edge
terminates WebRTC SIP/WSS domains and applies Kamailio signaling policy. RTP
media relay is owned by dedicated `mnscloud-media` nodes.

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
GET /api/v1/realtime/webrtc/edge/config
```

The response describes domains, PABX targets, the rtpengine NG control socket,
and edge policy.

## Data Plane

Kamailio handles signaling. Dedicated media nodes handle RTP/SRTP relay.

```text
WSS -> Nginx -> Kamailio -> PABX
             -> mnscloud-media / rtpengine -> RTP/SRTP media
```

The Nginx process in this diagram is local to the WebRTC edge host. It is not
the generic MNSCloud edge gateway used for App/API traffic. Do not collapse SIP,
RTP, TURN/STUN, or SFU media into the main HTTP edge.

## Edge Boundaries

HTTP application edge:

- App/API/Website/Customer Portal.
- Web clients such as PhoneWeb or a future WebRTC portal.
- Application-level WebSockets for chat, presence, notifications, or business
  signaling when intentionally designed as HTTP/WebSocket services.

WebRTC edge:

- SIP over secure WebSocket.
- WebRTC SIP domain certificates.
- Kamailio routing, authentication hooks, and tenant/domain signaling policy.
- rtpengine NG socket integration.

Media edge:

- RTP/SRTP media relay through `mnscloud-media`.
- TURN/STUN and SFU/video media stay in dedicated realtime modules, not generic
  Nginx locations.
