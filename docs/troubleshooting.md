# Troubleshooting

Check service status:

```bash
systemctl status nginx kamailio --no-pager
```

Validate configuration:

```bash
sudo bash /opt/mnscloud/kamailio-webrtc/scripts/validate-kamailio-webrtc.sh
nginx -t
kamailio -c -f /etc/kamailio/kamailio.cfg
```

Inspect listeners:

```bash
ss -lntup
```

Check PABX SIP reachability from the edge:

```bash
nc -zvw3 <pabx-host> 5060
ping -c 3 <pabx-host>
traceroute <pabx-host>
```

Trace SIP registration traffic:

```bash
sudo ngrep -d any -W byline "REGISTER|SIP/2.0" udp port 5060
sudo tcpdump -ni any host <pabx-host> and port 5060
```

Check logs:

```bash
journalctl -u kamailio -n 200 --no-pager
journalctl -u nginx -n 200 --no-pager
```

Common issues:

- Assigned Agent is offline or missing `realtime.webrtc.manage`
- Public DNS not pointing to the edge server
- TLS not configured yet
- Cyber Security profile not applied for RTP UDP range on the media node
- PABX target unreachable from the edge server
- Kamailio module initialization errors:
  - `nathelper ... can't find usrloc module` means the template is missing the
    `usrloc` dependency required for NAT ping support.
  - `auth_db ... unable to bind to a database driver` means database-backed
    authentication is loaded without a database driver. This edge is
    API/control-plane driven and must not require local database authentication.
- rtpengine service errors are owned by the dedicated `mnscloud-media` host.
  Validate that runtime with `sudo bash /opt/mnscloud/media/scripts/validate-media.sh`.
- The sync service restarts Kamailio after rendering `/etc/kamailio/kamailio.cfg`.
  Kamailio native configuration file changes require restart; module data
  reloads via RPC are separate, module-specific operations.
