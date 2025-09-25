# Hi, I'm Samuel Jackson!
**[System Development Engineer](https://github.com/sams-jackson)** · **[DevOps & QA Enthusiast](https://www.linkedin.com/in/sams-jackson)** · **[Homelab Builder](https://www.youtube.com/@yourchannel)**

*Building reliable systems, documenting clearly, and sharing what I learn. I turn ambiguous requirements into runbooks, dashboards, and repeatable processes.*

**Status key:** 🟢 Done · 🟠 In Progress · 🔵 Planned

---

## 🎯 Summary
System-minded engineer specializing in building, securing, and operating infrastructure and data-heavy web systems. Hands-on with homelab → production-like setups (wired rack, UniFi network, VPN, NAS), virtualization/services (Proxmox/TrueNAS), and observability/backups. Commercial experience shipping and maintaining booking/e-commerce sites with tens of thousands of SKUs and weekly price updates via SQL-driven workflows.

<details>
<summary><strong>Alternate summaries for tailoring</strong></summary>

**DevOps-forward**  
DevOps-leaning systems engineer who builds and operates reliable services end-to-end: homelab→production patterns (networking, virtualization, reverse proxy + TLS, backups), metrics/alerts (Prometheus/Grafana/Loki/Alertmanager), and automation with PowerShell/Bash/SQL. Experienced with data-heavy e-commerce/booking systems and operational runbooks.

**QA-forward**  
Quality-driven systems engineer turning ambiguous requirements into testable runbooks, acceptance criteria, and regression checklists. Builds monitoring dashboards for golden signals, designs reliable backup/restore procedures, and uses SQL/automation to validate data integrity across high-SKU catalogs and booking systems.
</details>

---

## 🛠️ Core Skills
- **Systems & Infra:** Linux/Windows, networking, VLANs, VPN, UniFi, NAS, Active Directory  
- **Virtualization/Services:** Proxmox/TrueNAS, reverse proxy + TLS, RBAC/MFA, backup/restore drills  
- **Automation & Scripting:** PowerShell, Bash, SQL (catalog ops, reporting), Git  
- **Web & Data:** WordPress, e-commerce/booking systems, schema design, large-catalog data ops  
- **Observability & Reliability:** Prometheus, Grafana, Loki, Alertmanager, golden signals, SLOs, PBS  
- **Cloud & Tools:** AWS/Azure (baseline), GitHub, Docs/Sheets, Visio/diagramming  
- **Quality & Process:** runbooks, acceptance criteria, regression checklists, change control  

---

## 🟢 Completed Projects

### Homelab & Secure Network Build
**Description**  
Designed and wired a home network from scratch: rack-mounted gear, VLAN segmentation, and secure Wi-Fi for isolated IoT, guest, and trusted networks.

**Proposal**  
Secure, segment, and document a small-enterprise-grade home network enabling remote admin without expanding attack surface.

**Objectives & Goals**  
- O1: VLAN isolation and policies for IoT/guest/trusted networks  
- O2: VPN-only management access; least-privilege admin  
- O3: Documented network map + repeatable setup

**Architecture (logical)**  
```mermaid
flowchart LR
  Internet --> UDM[UniFi Router/Firewall]
  UDM --> SW[UniFi Switch]
  SW --> AP1[UniFi AP 1]
  SW --> AP2[UniFi AP 2]
  SW --> NAS
  UDM -->|VPN| Admin[Remote Admin]
