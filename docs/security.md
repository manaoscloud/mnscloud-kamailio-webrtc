# Security

Security policy is owned by the MNSCloud Cyber Security module and applied
through the MNSCloud Agent.

The WebRTC Edge installer does not require the Agent and does not install the
full firewall/security profile. This keeps service installation and security
policy clearly separated.

Recommended Cyber Security profile:

```text
WebRTC Edge
```

Protected services:

- Linux
- SSH
- Nginx
- Kamailio
- rtpengine

Recommended public ports:

```text
443/tcp
30000-40000/udp
```

The installer may create a temporary self-signed certificate when no TLS
certificate is installed. This is only a bootstrapping fallback. Public WebRTC
clients should use a trusted certificate for the edge public domain.

Do not expose Kamailio admin ports or rtpengine control ports publicly.

Do not expose SIP/WSS, RTP/SRTP, TURN/STUN, SFU media, rtpengine control, or
PABX ports through the generic MNSCloud HTTP edge. Keep private keys on the node
that terminates the relevant TLS domain, and keep routing ownership in the
MNSCloud API/control plane.
