# Scaling

## Single Node

```text
Nginx + Kamailio signaling edge
Dedicated mnscloud-media node for RTP/SRTP relay
```

This is the recommended starting point.

## Regional Edge Cluster

```text
DNS / Load Balancer
  -> WebRTC Edge 01
  -> WebRTC Edge 02
  -> WebRTC Edge 03
```

Each WebRTC signaling node runs Nginx and Kamailio. Media relay capacity scales
through dedicated `mnscloud-media` nodes.

Use realtime-aware DNS, load balancing, or explicit domain/node assignment for
WebRTC edges. Do not use the generic `mnscloud-nginx` App/API edge as the
scaling layer for RTP/SRTP or rtpengine media.

## Large Scale

```text
GeoDNS / Anycast / Global Load Balancer
        |
Kamailio signaling edge cluster
        |
mnscloud-media / rtpengine media cluster
        |
PABX pools
        |
MNSCloud API control plane
```

At large scale, media nodes are separated from signaling nodes.

The HTTP application edge can scale independently for App/API/web clients. The
WebRTC signaling and media planes should scale independently by region, domain
assignment, health, and capacity from the MNSCloud control plane.
