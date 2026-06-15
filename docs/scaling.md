# Scaling

## Single Node

```text
Nginx + Kamailio + rtpengine
```

This is the recommended starting point.

## Regional Edge Cluster

```text
DNS / Load Balancer
  -> WebRTC Edge 01
  -> WebRTC Edge 02
  -> WebRTC Edge 03
```

Each node runs Nginx, Kamailio, and rtpengine.

Use realtime-aware DNS, load balancing, or explicit domain/node assignment for
WebRTC edges. Do not use the generic `mnscloud-nginx` App/API edge as the
scaling layer for RTP/SRTP or rtpengine media.

## Large Scale

```text
GeoDNS / Anycast / Global Load Balancer
        |
Kamailio signaling edge cluster
        |
rtpengine media cluster
        |
PABX pools
        |
MNSCloud API control plane
```

At large scale, media nodes can be separated from signaling nodes.

The HTTP application edge can scale independently for App/API/web clients. The
WebRTC signaling/media plane should scale by region, domain assignment, health,
and capacity from the MNSCloud control plane.
