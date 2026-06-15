# AGENTS.md

This repository is a standalone public MNSCloud client, installer, agent, or edge connector.

## Repository

- Name: mnscloud-kamailio-webrtc
- Public boundary: consumes the MNSCloud API/control plane and must not contain private platform authority.

## Contribution Workflow

- Contributions must use Pull Requests.
- Follow `CONTRIBUTING.md`, `SECURITY.md`, and `SKILL.md`.
- Run repository validation before committing.
- Do not leave completed changes uncommitted or unpushed when working as a maintainer.

## Security Boundary

Never commit secrets, tokens, customer data, provider credentials, database credentials, production
IP addresses/domains, private infrastructure topology, master keys, hidden bypasses, or private
business rules.

Authorization, tenant scope, billing, routing ownership, policy decisions, and secret resolution must
remain in the MNSCloud API/control plane.

## Realtime Edge Boundary

This repository owns WebRTC SIP/WSS signaling, local WebRTC TLS termination,
Kamailio routing, and rtpengine media anchoring. Do not move SIP/RTP/TURN/SFU
behavior into the generic `mnscloud-nginx` HTTP edge. Browser UI clients may be
published by the HTTP edge, but realtime signaling/media stays in this module
or future dedicated realtime modules.

## Paid Contributions

MNSCloud may choose to pay, sponsor, contract, or hire contributors whose work demonstrates strong
value. Paid work requires explicit written agreement and is never implied by opening a Pull Request.
