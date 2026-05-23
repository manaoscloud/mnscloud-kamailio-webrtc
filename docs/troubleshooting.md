# Troubleshooting

Check service status:

```bash
systemctl status nginx kamailio rtpengine --no-pager
```

Validate configuration:

```bash
nginx -t
kamailio -c -f /etc/kamailio/kamailio.cfg
```

Inspect listeners:

```bash
ss -lntup
```

Check logs:

```bash
journalctl -u kamailio -n 200 --no-pager
journalctl -u rtpengine -n 200 --no-pager
journalctl -u nginx -n 200 --no-pager
```

Common issues:

- Assigned Agent is offline or missing `webrtc.kamailio.manage`
- Public DNS not pointing to the edge server
- TLS not configured yet
- Cyber Security profile not applied for RTP UDP range
- PABX target unreachable from the edge server
- Kamailio module initialization errors:
  - `nathelper ... can't find usrloc module` means the template is missing the
    `usrloc` dependency required for NAT ping support.
  - `auth_db ... unable to bind to a database driver` means database-backed
    authentication is loaded without a database driver. This edge is
    API/control-plane driven and must not require local database authentication.
- `rtpengine` can start with `KERNEL FORWARDING DISABLED` when the running
  kernel headers are not installed and the DKMS module cannot be built. The
  installer attempts to install `linux-headers-$(uname -r)` automatically. When
  that package is not available from the host repositories, align the provider
  kernel with available headers or keep rtpengine in userspace mode.
- `rtpengine` fails with `Invalid interface specification: '0.0.0.0'` when the
  media interface is configured as a wildcard bind address. Use `interface=any`,
  a concrete local IP, a system interface name, or `local!advertised` when the
  edge is behind NAT.
- On dual-stack nodes with IPv4 behind NAT and directly routed IPv6, configure
  rtpengine with both addresses in one line, separated by `;`, for example
  `interface=10.0.0.10!203.0.113.10;2001:db8::10`.
- The sync service restarts Kamailio after rendering `/etc/kamailio/kamailio.cfg`.
  Kamailio native configuration file changes require restart; module data
  reloads via RPC are separate, module-specific operations.
