# MNSCloud Kamailio WebRTC Edge Skill

Use this skill when working on the standalone MNSCloud Kamailio WebRTC Edge
repository.

## Language

All repository code comments, documentation, scripts, commit messages, examples,
and public-facing text must be written in English.

## Public Repository Rules

- Do not commit secrets, real tokens, customer data, private domains, production
  IP addresses, provider credentials, database credentials, API master keys, or
  private infrastructure topology.
- Use placeholders such as `webrtc.example.com`, `203.0.113.10`, and
  `10.0.0.10`.
- Keep tenant authorization, billing rules, routing ownership, and secret
  resolution in the MNSCloud API/control plane.
- The edge consumes `GET /api/v1/webrtc/edge/config` and renders local service
  configuration from that response.

## Architecture Rules

- The canonical WebRTC identity is `extension@domain`.
- Never authenticate or route by extension username alone.
- Render domain-based PABX routing from the API `pabxTargets` runtime payload.
  If a domain has no target, Kamailio must fail closed with `No PABX target`
  instead of using stale dispatcher state or forwarding back to itself.
- Generate Kamailio listeners from runtime config. Public WebSocket traffic
  terminates on Nginx, while SIP listeners must stay on loopback/private
  interfaces needed to reach the PABX.
- Keep Kamailio as the signaling SBC, rtpengine as the media relay, and PABX
  servers internal.
- Do not require the MNSCloud Agent during service installation. Cyber Security
  profiles are applied separately through the Agent.
- The MNSCloud Agent may optionally trigger immediate reconciliation through
  `webrtc.kamailio.manage` and `webrtc.edge.sync`; keep the timer/service sync
  path as the standalone fallback.
- Nginx must be installed from the official stable nginx.org repository.
- The current full WebRTC installer supports Debian 12/13 because Kamailio and
  rtpengine package installation is Debian-based.

## Validation

After changes, run the relevant shell checks:

```bash
bash -n scripts/install-kamailio-webrtc.sh
bash -n scripts/update-kamailio-webrtc.sh
bash -n scripts/uninstall-kamailio-webrtc.sh
```

Commit and push completed changes to the corresponding GitHub repository.


## Contribution Governance

- External contributions must be submitted through Pull Requests.
- Follow `CONTRIBUTING.md`, `SECURITY.md`, `AGENTS.md`, and this `SKILL.md` before proposing changes.
- Do not add secrets, customer data, private infrastructure details, production domains/IPs, or hidden bypass logic.
- MNSCloud may choose to pay, sponsor, contract, or hire contributors when work demonstrates strong value, but paid work requires explicit written agreement and is never implied by opening a Pull Request.
- Keep security-sensitive decisions, tenant scope, billing, authorization, routing ownership, and secret resolution in the MNSCloud API/control plane.
