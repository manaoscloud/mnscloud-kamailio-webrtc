# Security Policy

This repository is public and must never contain permanent secrets, customer
data, production IP addresses, private infrastructure topology, provider
credentials, database credentials, API master keys, or internal business rules.

## Responsibility Split

MNSCloud Kamailio WebRTC Edge is an edge connector. It consumes the MNSCloud API
contract and receives authorized configuration from the control plane.

The edge must not become the only enforcement layer for:

- tenant authorization
- billing policy
- ownership decisions
- secret resolution
- routing ownership
- customer data access

Those decisions remain inside the MNSCloud API/control plane.

## Production Hardening

Production deployments should apply the MNSCloud Cyber Security WebRTC Edge
profile through the MNSCloud Agent. That profile is responsible for nftables,
CrowdSec, bouncers, service profiles, and firewall policy.

This installer only applies local service hardening and safe file permissions.

## Reporting Vulnerabilities

Please report vulnerabilities privately to the MNSCloud maintainers. Do not open
public issues containing exploit details, secrets, or customer-identifying data.

