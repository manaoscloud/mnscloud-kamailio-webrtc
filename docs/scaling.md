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

