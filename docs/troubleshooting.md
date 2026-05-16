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

- Node token missing in `/etc/mnscloud/kamailio-webrtc/node.token`
- Public DNS not pointing to the edge server
- TLS not configured yet
- Cyber Security profile not applied for RTP UDP range
- PABX target unreachable from the edge server

