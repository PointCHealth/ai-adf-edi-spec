# Azure Networking Architecture

**Project:** Healthcare EDI Platform  
**Last Updated:** 2025-10-05  
**Owner:** Platform Engineering Team

---

## Overview

This document defines the network architecture for the Healthcare EDI Platform, including Virtual Network (VNet) design, subnet allocation, Network Security Groups (NSGs), private endpoints, and firewall rules. The architecture prioritizes **security**, **HIPAA compliance**, and **defense-in-depth** principles.

---

## Architecture Principles

1. **Network Isolation:** Azure resources deployed in private VNet subnets
2. **Private Endpoints:** PaaS services accessed via private endpoints (no public internet exposure)
3. **Zero Trust:** All traffic authenticated and authorized
4. **Defense in Depth:** Multiple layers of security (NSGs, firewalls, WAF)
5. **Regional Deployment:** Single region (East US 2) to minimize latency
6. **Static Outbound IP:** NAT Gateway for partner IP whitelisting
7. **Hub-Spoke Topology:** Shared hub VNet for centralized security (future phase)

---

## Network Topology

### Single Region Architecture (Phase 1)

```
┌────────────────────────────────────────────────────────────┐
│                  Azure Virtual Network                     │
│              vnet-edi-prod-eastus2 (10.100.0.0/16)        │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ┌──────────────────────────────────────────────────┐    │
│  │ Function Subnet (10.100.1.0/24)                  │    │
│  │ - All Azure Functions (VNet integrated)          │    │
│  │ - NAT Gateway attached                           │    │
│  │ - NSG: nsg-functions-prod                        │    │
│  └──────────────────────────────────────────────────┘    │
│                                                            │
│  ┌──────────────────────────────────────────────────┐    │
│  │ Private Endpoint Subnet (10.100.2.0/24)          │    │
│  │ - Storage Account private endpoints              │    │
│  │ - Service Bus private endpoints                  │    │
│  │ - SQL Database private endpoints                 │    │
│  │ - Key Vault private endpoints                    │    │
│  │ - NSG: nsg-privatelink-prod                      │    │
│  └──────────────────────────────────────────────────┘    │
│                                                            │
│  ┌──────────────────────────────────────────────────┐    │
│  │ Management Subnet (10.100.3.0/27)                │    │
│  │ - Bastion Host (future)                          │    │
│  │ - Jump box VMs (future)                          │    │
│  │ - NSG: nsg-management-prod                       │    │
│  └──────────────────────────────────────────────────┘    │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Virtual Network Configuration

### Production Environment

**VNet Name:** `vnet-edi-prod-eastus2`  
**Address Space:** `10.100.0.0/16` (65,536 addresses)  
**Region:** East US 2  
**DNS:** Azure-provided DNS (168.63.129.16)

### Test Environment

**VNet Name:** `vnet-edi-test-eastus2`  
**Address Space:** `10.101.0.0/16`  
**Region:** East US 2

### Dev Environment

**VNet Name:** `vnet-edi-dev-eastus2`  
**Address Space:** `10.102.0.0/16`  
**Region:** East US 2

---

## Subnet Design

### Production Subnets

| Subnet Name | Address Range | Available IPs | Purpose | Delegations |
|------------|---------------|---------------|---------|-------------|
| `snet-functions-prod-eastus2` | 10.100.1.0/24 | 251 | Azure Functions VNet integration | Microsoft.Web/serverFarms |
| `snet-privatelink-prod-eastus2` | 10.100.2.0/24 | 251 | Private endpoints for PaaS services | None |
| `snet-management-prod-eastus2` | 10.100.3.0/27 | 27 | Management/Bastion (future) | None |
| `snet-appgateway-prod-eastus2` | 10.100.4.0/24 | 251 | Application Gateway (future) | None |

**Reserved Subnets (Future):**
- `snet-azurefirewall-prod-eastus2` (10.100.10.0/26) - Azure Firewall
- `snet-vpngateway-prod-eastus2` (10.100.11.0/27) - VPN Gateway

### Test/Dev Subnets

Same naming pattern with corresponding address spaces (10.101.x.x for test, 10.102.x.x for dev).

---

## Network Security Groups (NSGs)

### NSG: nsg-functions-prod-eastus2

**Applied To:** `snet-functions-prod-eastus2`

**Inbound Rules:**

| Priority | Name | Source | Source Port | Destination | Dest Port | Protocol | Action |
|---------|------|--------|-------------|-------------|-----------|----------|--------|
| 100 | AllowAzureLoadBalancer | AzureLoadBalancer | * | * | * | Any | Allow |
| 110 | AllowVNetInbound | VirtualNetwork | * | VirtualNetwork | * | Any | Allow |
| 4096 | DenyAllInbound | * | * | * | * | Any | Deny |

**Outbound Rules:**

| Priority | Name | Source | Source Port | Destination | Dest Port | Protocol | Action |
|---------|------|--------|-------------|-------------|-----------|----------|--------|
| 100 | AllowPrivateLinkSubnet | VirtualNetwork | * | 10.100.2.0/24 | 443,1433,5671-5672 | TCP | Allow |
| 110 | AllowAzureMonitor | * | * | AzureMonitor | * | Any | Allow |
| 120 | AllowAzureStorage | * | * | Storage.EastUS2 | 443 | TCP | Allow |
| 130 | AllowInternetHTTPS | * | * | Internet | 443 | TCP | Allow |
| 140 | AllowPartnerSftp | * | * | Internet | 22 | TCP | Allow |
| 4096 | DenyAllOutbound | * | * | * | * | Any | Deny |

**Rationale:**
- Functions need outbound HTTPS for Azure dependencies (Storage, Service Bus via private link)
- SFTP connector needs port 22 for partner connections
- Azure Monitor for telemetry
- Deny all other traffic by default

---

### NSG: nsg-privatelink-prod-eastus2

**Applied To:** `snet-privatelink-prod-eastus2`

**Inbound Rules:**

| Priority | Name | Source | Source Port | Destination | Dest Port | Protocol | Action |
|---------|------|--------|-------------|-------------|-----------|----------|--------|
| 100 | AllowFunctionsToStorage | 10.100.1.0/24 | * | * | 443 | TCP | Allow |
| 110 | AllowFunctionsToServiceBus | 10.100.1.0/24 | * | * | 5671-5672 | TCP | Allow |
| 120 | AllowFunctionsToSQL | 10.100.1.0/24 | * | * | 1433 | TCP | Allow |
| 130 | AllowFunctionsToKeyVault | 10.100.1.0/24 | * | * | 443 | TCP | Allow |
| 4096 | DenyAllInbound | * | * | * | * | Any | Deny |

**Outbound Rules:**

| Priority | Name | Source | Source Port | Destination | Dest Port | Protocol | Action |
|---------|------|--------|-------------|-------------|-----------|----------|--------|
| 100 | AllowAzureMonitor | * | * | AzureMonitor | * | Any | Allow |
| 4096 | DenyAllOutbound | * | * | * | * | Any | Deny |

---

### NSG: nsg-management-prod-eastus2

**Applied To:** `snet-management-prod-eastus2` (Future use)

**Inbound Rules:**

| Priority | Name | Source | Source Port | Destination | Dest Port | Protocol | Action |
|---------|------|--------|-------------|-------------|-----------|----------|--------|
| 100 | AllowBastionSSH | AzureBastionSubnet | * | * | 22 | TCP | Allow |
| 110 | AllowBastionRDP | AzureBastionSubnet | * | * | 3389 | TCP | Allow |
| 4096 | DenyAllInbound | * | * | * | * | Any | Deny |

---

## Private Endpoints

### Storage Account Private Endpoints

**Resource:** `stediprodeastus2`  
**Subnet:** `snet-privatelink-prod-eastus2`  
**Private IP:** Dynamically assigned (e.g., 10.100.2.10)

**Subresource Targets:**
- `blob` - Blob storage access
- `file` - File share access (if needed)
- `queue` - Queue storage (optional)
- `table` - Table storage (optional)

**DNS Zone:** `privatelink.blob.core.windows.net`

**A Records:**
```
stediprodeastus2.privatelink.blob.core.windows.net -> 10.100.2.10
```

---

### Service Bus Private Endpoint

**Resource:** `sb-edi-prod-eastus2`  
**Subnet:** `snet-privatelink-prod-eastus2`  
**Private IP:** Dynamically assigned (e.g., 10.100.2.11)

**Subresource Target:** `namespace`

**DNS Zone:** `privatelink.servicebus.windows.net`

**A Records:**
```
sb-edi-prod-eastus2.privatelink.servicebus.windows.net -> 10.100.2.11
```

---

### SQL Database Private Endpoint

**Resource:** `sql-edi-prod-eastus2.database.windows.net`  
**Subnet:** `snet-privatelink-prod-eastus2`  
**Private IP:** Dynamically assigned (e.g., 10.100.2.12)

**Subresource Target:** `sqlServer`

**DNS Zone:** `privatelink.database.windows.net`

**A Records:**
```
sql-edi-prod-eastus2.privatelink.database.windows.net -> 10.100.2.12
```

---

### Key Vault Private Endpoint

**Resource:** `kv-edi-prod-eastus2`  
**Subnet:** `snet-privatelink-prod-eastus2`  
**Private IP:** Dynamically assigned (e.g., 10.100.2.13)

**Subresource Target:** `vault`

**DNS Zone:** `privatelink.vaultcore.azure.net`

**A Records:**
```
kv-edi-prod-eastus2.privatelink.vaultcore.azure.net -> 10.100.2.13
```

---

## Private DNS Zones

All private DNS zones are linked to the VNet to enable name resolution of private endpoints.

### Required Private DNS Zones

| Service | DNS Zone |
|---------|----------|
| Storage (Blob) | `privatelink.blob.core.windows.net` |
| Storage (File) | `privatelink.file.core.windows.net` |
| Service Bus | `privatelink.servicebus.windows.net` |
| SQL Database | `privatelink.database.windows.net` |
| Key Vault | `privatelink.vaultcore.azure.net` |
| Application Insights | `privatelink.monitor.azure.com` |

### VNet Links

Each private DNS zone must be linked to all environment VNets:
- `vnet-edi-prod-eastus2`
- `vnet-edi-test-eastus2`
- `vnet-edi-dev-eastus2`

---

## NAT Gateway

### Purpose

Provide static outbound IP address for partner SFTP IP whitelisting.

**Resource Name:** `nat-edi-prod-eastus2`  
**Region:** East US 2  
**Attached Subnet:** `snet-functions-prod-eastus2`

**Public IP Address:**  
- **Name:** `pip-nat-edi-prod-eastus2`
- **SKU:** Standard
- **Allocation:** Static
- **IP Example:** `52.x.x.x` (assigned by Azure)

**Configuration:**
- Idle timeout: 10 minutes
- TCP reset: Enabled

**Partners Whitelisting:** Provide `52.x.x.x` to all trading partners for SFTP access.

---

## Function App VNet Integration

### Configuration

All Function Apps must be VNet-integrated to the function subnet.

**Settings:**
```json
{
  "subnetResourceId": "/subscriptions/{sub}/resourceGroups/rg-edi-prod-eastus2/providers/Microsoft.Network/virtualNetworks/vnet-edi-prod-eastus2/subnets/snet-functions-prod-eastus2",
  "swiftSupported": true
}
```

**Application Settings:**
```json
{
  "WEBSITE_VNET_ROUTE_ALL": "1",
  "WEBSITE_DNS_SERVER": "168.63.129.16"
}
```

**Effect:**
- All outbound traffic from functions routes through VNet
- Functions access PaaS services via private endpoints
- Outbound internet traffic uses NAT Gateway

---

## Firewall Rules

### Storage Account Firewall

**Public Network Access:** Disabled (after private endpoint configured)

**Firewall Rules:**
- Allow access from `vnet-edi-prod-eastus2` (VNet rule)
- Deny all other traffic

**Exceptions:**
- Allow trusted Microsoft services: **Enabled** (for Azure Backup, Monitoring)

---

### Service Bus Firewall

**Public Network Access:** Disabled

**Network Rules:**
- Allow access from `snet-functions-prod-eastus2`
- Deny all other traffic

---

### SQL Database Firewall

**Public Network Access:** Disabled

**Firewall Rules:**
- Allow VNet rule: `snet-functions-prod-eastus2`
- Allow Azure services: **Disabled** (use private endpoint)

**Connection Policy:** Redirect (for best performance within VNet)

---

### Key Vault Firewall

**Public Network Access:** Disabled

**Network Rules:**
- Allow access from `snet-functions-prod-eastus2`
- Deny all other traffic

**Exceptions:**
- Allow trusted Microsoft services: **Enabled** (for Azure DevOps, GitHub Actions)

---

## Traffic Flow Diagrams

### Inbound File Processing

```
Partner SFTP Server
    ↓ (upload file)
SftpConnector Function (10.100.1.x)
    ↓ (via NAT Gateway 52.x.x.x)
    ↓
    ↓ (write to blob)
Storage Private Endpoint (10.100.2.10)
    ↓
Storage Account (stediprodeastus2)
    ↓ (Event Grid event)
InboundRouter Function (10.100.1.y)
    ↓ (publish message)
Service Bus Private Endpoint (10.100.2.11)
    ↓
Service Bus (sb-edi-prod-eastus2)
```

### Outbound HTTP/HTTPS

```
Azure Function (10.100.1.x)
    ↓ (outbound HTTPS)
NAT Gateway (52.x.x.x)
    ↓
Internet (partner API)
```

### Database Access

```
Azure Function (10.100.1.x)
    ↓ (SQL query, port 1433)
SQL Private Endpoint (10.100.2.12)
    ↓
SQL Database (sql-edi-prod-eastus2)
```

---

## IP Address Allocation

### Production Environment

| Component | Subnet | IP Range | Expected Usage |
|-----------|--------|----------|----------------|
| Function Apps (12 apps, max 30 instances each) | 10.100.1.0/24 | 10.100.1.4 - 10.100.1.254 | ~100 IPs |
| Private Endpoints (5 services) | 10.100.2.0/24 | 10.100.2.4 - 10.100.2.20 | ~10 IPs |
| Management (future) | 10.100.3.0/27 | 10.100.3.4 - 10.100.3.30 | ~5 IPs |

**Note:** First 3 IPs in each subnet reserved by Azure.

---

## Security Best Practices

### Defense in Depth

1. **Layer 1 - NSGs:** Control traffic at subnet level
2. **Layer 2 - Private Endpoints:** No public internet exposure for PaaS
3. **Layer 3 - Service Firewalls:** Whitelist only VNet access
4. **Layer 4 - RBAC:** Managed identity with least privilege
5. **Layer 5 - Encryption:** TLS 1.2+ in transit, AES-256 at rest

### Zero Trust Implementation

- **Never Trust, Always Verify:** Every request authenticated
- **Least Privilege Access:** Functions use managed identity with minimal RBAC roles
- **Assume Breach:** Monitor all traffic, log all access

---

## Monitoring & Diagnostics

### Network Watcher

**Enabled Features:**
- NSG Flow Logs (sent to Log Analytics)
- Connection Monitor (test connectivity to private endpoints)
- Packet Capture (on-demand troubleshooting)

### NSG Flow Logs

**Configuration:**
```json
{
  "targetResourceId": "/subscriptions/{sub}/resourceGroups/rg-edi-prod-eastus2/providers/Microsoft.Network/networkSecurityGroups/nsg-functions-prod",
  "storageId": "/subscriptions/{sub}/resourceGroups/rg-edi-prod-eastus2/providers/Microsoft.Storage/storageAccounts/stedilogsprod",
  "enabled": true,
  "retentionPolicy": {
    "days": 90,
    "enabled": true
  },
  "format": {
    "type": "JSON",
    "version": 2
  }
}
```

### KQL Queries for Network Monitoring

**Denied traffic by NSG:**

```kql
AzureNetworkAnalytics_CL
| where SubType_s == "FlowLog"
| where FlowStatus_s == "D" // Denied
| summarize count() by NSGList_s, DestIP_s, DestPort_d
| order by count_ desc
```

**Private endpoint connection failures:**

```kql
AzureDiagnostics
| where ResourceType == "PRIVATEENDPOINTS"
| where Category == "PrivateLinkProxyConnections"
| where Status_s == "Failed"
| summarize count() by Resource, bin(TimeGenerated, 5m)
```

---

## Disaster Recovery

### Network Resilience

**Current State (Single Region):**
- VNet in East US 2 only
- No cross-region connectivity

**Future State (Multi-Region):**
- Secondary VNet in West US 2
- VNet peering between regions
- Azure Traffic Manager for failover

### Backup Connectivity

**Temporary Public Access (Emergency Only):**
1. Enable public network access on storage/SQL
2. Add temporary firewall rule for specific IP
3. Revert changes after incident resolved

---

## Deployment Checklist

- [ ] Create VNet with subnets
- [ ] Create NSGs and apply to subnets
- [ ] Create NAT Gateway with public IP
- [ ] Attach NAT Gateway to function subnet
- [ ] Create private DNS zones
- [ ] Link private DNS zones to VNets
- [ ] Deploy Azure resources (Storage, Service Bus, SQL, Key Vault)
- [ ] Create private endpoints for each service
- [ ] Configure VNet integration for all Function Apps
- [ ] Disable public network access on all PaaS services
- [ ] Test connectivity from functions to private endpoints
- [ ] Verify outbound IP via NAT Gateway
- [ ] Provide NAT Gateway public IP to partners for whitelisting
- [ ] Enable NSG flow logs
- [ ] Configure Network Watcher connection monitors

---

## Bicep Template Example

```bicep
// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-edi-prod-eastus2'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.100.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-functions-prod-eastus2'
        properties: {
          addressPrefix: '10.100.1.0/24'
          networkSecurityGroup: {
            id: nsgFunctions.id
          }
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          natGateway: {
            id: natGateway.id
          }
        }
      }
      {
        name: 'snet-privatelink-prod-eastus2'
        properties: {
          addressPrefix: '10.100.2.0/24'
          networkSecurityGroup: {
            id: nsgPrivateLink.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// NAT Gateway
resource natGateway 'Microsoft.Network/natGateways@2023-05-01' = {
  name: 'nat-edi-prod-eastus2'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: publicIp.id
      }
    ]
    idleTimeoutInMinutes: 10
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-nat-edi-prod-eastus2'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}
```

---

**Last Updated:** 2025-10-05  
**Owner:** Platform Engineering Team  
**Review Schedule:** Quarterly
