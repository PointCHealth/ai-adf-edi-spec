# Azure Resource Sizing Guide

**Project:** Healthcare EDI Platform  
**Last Updated:** October 5, 2025  
**Owner:** Platform Engineering Team

---

## Overview

This document defines the Azure resource sizing, SKUs, and scaling configurations for all environments (dev, test, prod). These specifications feed into the Bicep templates and ensure consistent, cost-effective infrastructure deployment.

---

## Environment Strategy

| Environment | Purpose | Sizing Strategy | Cost Target |
|------------|---------|----------------|-------------|
| **Dev** | Development, AI-assisted coding | Minimal SKUs, auto-pause features | <$500/month |
| **Test** | UAT, partner testing, integration tests | Mid-tier SKUs, limited scale | <$1,000/month |
| **Prod** | Production workloads | Premium SKUs, auto-scale, redundancy | <$5,000/month |

---

## Azure Functions

### Dev Environment

```bicep
{
  "sku": {
    "name": "EP1",  // Elastic Premium Plan
    "tier": "ElasticPremium",
    "size": "EP1",
    "family": "EP",
    "capacity": 1
  },
  "properties": {
    "reserved": false,  // Windows
    "maximumElasticWorkerCount": 3,
    "targetWorkerCount": 1,
    "targetWorkerSizeId": 3  // EP1: 1 vCPU, 3.5 GB RAM
  }
}
```

**Configuration:**
- **Plan:** EP1 (1 vCPU, 3.5 GB RAM)
- **Always On:** Yes (Premium plan)
- **Pre-warmed instances:** 1
- **Maximum scale out:** 3 instances
- **Runtime:** .NET 9 Isolated

**Functions on this plan:**
- InboundRouter
- OutboundOrchestrator
- X12Parser
- MapperEngine
- ControlNumberGenerator
- FileArchiver
- NotificationService

**Cost:** ~$150/month (1 instance always on)

### Test Environment

```bicep
{
  "sku": {
    "name": "EP1",
    "tier": "ElasticPremium",
    "size": "EP1",
    "capacity": 1
  },
  "properties": {
    "maximumElasticWorkerCount": 5,
    "targetWorkerCount": 1,
    "targetWorkerSizeId": 3
  }
}
```

**Configuration:**
- **Plan:** EP1 (1 vCPU, 3.5 GB RAM)
- **Pre-warmed instances:** 1
- **Maximum scale out:** 5 instances
- **Same functions as dev**

**Cost:** ~$150-300/month (scales during testing)

### Production Environment

```bicep
{
  "sku": {
    "name": "EP2",  // Larger SKU for production
    "tier": "ElasticPremium",
    "size": "EP2",
    "capacity": 2  // Start with 2 instances for availability
  },
  "properties": {
    "maximumElasticWorkerCount": 30,  // Can scale to 30 instances
    "targetWorkerCount": 2,
    "targetWorkerSizeId": 4,  // EP2: 2 vCPU, 7 GB RAM
    "zoneRedundant": true  // High availability
  }
}
```

**Configuration:**
- **Plan:** EP2 (2 vCPU, 7 GB RAM)
- **Pre-warmed instances:** 2 (for availability)
- **Maximum scale out:** 30 instances
- **Zone redundancy:** Enabled
- **VNET integration:** Yes

**Auto-scale rules:**
- Scale out when: CPU > 70% or Queue depth > 100
- Scale in when: CPU < 30% and Queue depth < 10
- Cool down: 5 minutes

**Cost:** ~$600-2,000/month (depending on load)

---

## Azure Storage Accounts

### Dev Environment

```bicep
{
  "sku": {
    "name": "Standard_LRS"  // Locally redundant
  },
  "kind": "StorageV2",
  "properties": {
    "minimumTlsVersion": "TLS1_2",
    "supportsHttpsTrafficOnly": true,
    "allowBlobPublicAccess": false,
    "networkAcls": {
      "defaultAction": "Allow"  // Open for dev
    }
  }
}
```

**Configuration:**
- **Redundancy:** LRS (Locally Redundant Storage)
- **Performance:** Standard
- **Access tier:** Hot
- **Soft delete:** 7 days
- **Versioning:** Enabled
- **SFTP:** Enabled (for partner testing)

**Lifecycle management:**
- Move to Cool tier: After 30 days
- Move to Archive tier: After 90 days
- Delete: After 2 years (730 days)

**Cost:** ~$50/month (assuming 100 GB)

### Test Environment

```bicep
{
  "sku": {
    "name": "Standard_LRS"
  },
  "kind": "StorageV2",
  "properties": {
    "minimumTlsVersion": "TLS1_2",
    "supportsHttpsTrafficOnly": true,
    "allowBlobPublicAccess": false,
    "networkAcls": {
      "defaultAction": "Deny",
      "virtualNetworkRules": [
        {
          "subnetId": "[vnet subnet id]"
        }
      ]
    }
  }
}
```

**Configuration:**
- **Redundancy:** LRS
- **Performance:** Standard
- **Access tier:** Hot
- **Soft delete:** 14 days
- **Versioning:** Enabled
- **Private endpoints:** Optional

**Lifecycle management:**
- Move to Cool tier: After 60 days
- Move to Archive tier: After 180 days
- Delete: After 2555 days (7 years - HIPAA compliance)

**Cost:** ~$50-100/month

### Production Environment

```bicep
{
  "sku": {
    "name": "Standard_GRS"  // Geo-redundant
  },
  "kind": "StorageV2",
  "properties": {
    "minimumTlsVersion": "TLS1_2",
    "supportsHttpsTrafficOnly": true,
    "allowBlobPublicAccess": false,
    "accessTier": "Hot",
    "largeFileSharesState": "Enabled",
    "networkAcls": {
      "defaultAction": "Deny",
      "virtualNetworkRules": [
        {
          "subnetId": "[private endpoint subnet]"
        }
      ]
    }
  }
}
```

**Configuration:**
- **Redundancy:** GRS (Geo-Redundant Storage)
- **Performance:** Standard (Premium not needed for this workload)
- **Access tier:** Hot for active data
- **Soft delete:** 30 days
- **Versioning:** Enabled
- **Private endpoints:** Required
- **Encryption:** Customer-managed keys (optional)

**Lifecycle management:**
- Move to Cool tier: After 90 days
- Move to Archive tier: After 365 days
- Delete: After 2555 days (7 years - HIPAA compliance)

**Cost:** ~$150-400/month (GRS, 500 GB)

**Storage Accounts per Environment:**
1. **st-edi-raw-{env}-eastus2** - Raw inbound files
2. **st-edi-processed-{env}-eastus2** - Processed files
3. **st-edi-archive-{env}-eastus2** - Long-term archive

---

## Azure Service Bus

### Dev Environment

```bicep
{
  "sku": {
    "name": "Standard",
    "tier": "Standard"
  }
}
```

**Configuration:**
- **Tier:** Standard (no Premium features needed in dev)
- **Max message size:** 256 KB
- **Max queue size:** 1 GB per queue
- **Partitioning:** Disabled

**Queues:**
- inbound-router-queue (max delivery: 10, lock: 5 min)
- outbound-assembly-queue
- parser-queue
- mapper-queue
- notification-queue
- error-queue

**Topics:**
- transaction-events (for audit/analytics subscriptions)

**Cost:** ~$10/month (Standard tier base)

### Test Environment

```bicep
{
  "sku": {
    "name": "Standard",
    "tier": "Standard"
  }
}
```

**Configuration:**
- **Tier:** Standard
- **Same queues/topics as dev**

**Cost:** ~$10/month

### Production Environment

```bicep
{
  "sku": {
    "name": "Premium",
    "tier": "Premium",
    "capacity": 1  // 1 messaging unit
  },
  "properties": {
    "zoneRedundant": true
  }
}
```

**Configuration:**
- **Tier:** Premium (for VNET integration and better performance)
- **Messaging units:** 1 (can scale to 2-4 if needed)
- **Max message size:** 1 MB (Premium)
- **Max queue size:** 80 GB per queue
- **Partitioning:** Enabled where appropriate
- **Private endpoints:** Required
- **Zone redundancy:** Enabled

**Cost:** ~$650/month (Premium tier base)

**Alternative:** If cost is prohibitive, use Standard tier with firewall restrictions instead of Premium. Premium is recommended for:
- VNET integration
- Higher throughput
- Larger message sizes
- Zone redundancy

---

## Azure SQL Database

### Dev Environment

```bicep
{
  "sku": {
    "name": "Basic",
    "tier": "Basic",
    "capacity": 5  // 5 DTUs
  },
  "properties": {
    "maxSizeBytes": 2147483648  // 2 GB
  }
}
```

**Configuration:**
- **Tier:** Basic (5 DTUs)
- **Max size:** 2 GB
- **Backup retention:** 7 days
- **Geo-replication:** No
- **Private endpoint:** No (firewall rules)

**Databases:**
- EDI_ControlNumbers (stores ISA/GS control numbers)
- EDI_EventStore (event sourcing for transactions)
- EDI_Configuration (runtime configuration cache)

**Cost:** ~$5/month per database = $15/month total

### Test Environment

```bicep
{
  "sku": {
    "name": "S2",
    "tier": "Standard",
    "capacity": 50  // 50 DTUs
  },
  "properties": {
    "maxSizeBytes": 268435456000  // 250 GB
  }
}
```

**Configuration:**
- **Tier:** Standard S2 (50 DTUs)
- **Max size:** 250 GB
- **Backup retention:** 14 days
- **Geo-replication:** No
- **Private endpoint:** Optional

**Cost:** ~$75/month per database = $225/month total

**Alternative:** Use Elastic Pool for test if multiple databases:
```bicep
{
  "sku": {
    "name": "StandardPool",
    "tier": "Standard",
    "capacity": 100  // 100 DTUs shared across databases
  }
}
```
**Cost:** ~$150/month for pool

### Production Environment

```bicep
{
  "sku": {
    "name": "P2",
    "tier": "Premium",
    "capacity": 250  // 250 DTUs
  },
  "properties": {
    "maxSizeBytes": 536870912000,  // 500 GB
    "zoneRedundant": true,
    "readScale": "Enabled"
  }
}
```

**Configuration:**
- **Tier:** Premium P2 (250 DTUs)
- **Max size:** 500 GB
- **Backup retention:** 35 days
- **Geo-replication:** Yes (failover to secondary region)
- **Private endpoint:** Required
- **Zone redundancy:** Enabled
- **Read scale-out:** Enabled (for reporting queries)
- **TDE:** Enabled with customer-managed key (optional)

**Cost:** ~$900/month per database = $2,700/month total

**Alternative:** Use Elastic Pool for production:
```bicep
{
  "sku": {
    "name": "PremiumPool",
    "tier": "Premium",
    "capacity": 500  // 500 DTUs shared
  }
}
```
**Cost:** ~$1,800/month for pool (more cost-effective)

---

## Azure Data Factory

### All Environments

```bicep
{
  "properties": {
    "publicNetworkAccess": "Disabled",  // Prod only
    "managedVirtualNetwork": true
  }
}
```

**Configuration:**
- **Integration Runtime:** Azure Auto-Resolve IR (serverless)
- **Managed Virtual Network:** Enabled for prod
- **Git integration:** Enabled (GitHub)
- **Pricing tier:** Consumption-based (no reserved capacity)

**Cost:**
- **Dev:** ~$20/month (low activity)
- **Test:** ~$50/month (testing)
- **Prod:** ~$200/month (depends on pipeline runs)

**Optimization:**
- Use ADF primarily for scheduled jobs and data lake orchestration
- Use Azure Functions for event-driven transaction processing
- Batch small files before ADF processing

---

## Azure Key Vault

### Dev Environment

```bicep
{
  "sku": {
    "family": "A",
    "name": "standard"
  },
  "properties": {
    "enableSoftDelete": true,
    "softDeleteRetentionInDays": 90,
    "enablePurgeProtection": false  // Dev only
  }
}
```

**Configuration:**
- **SKU:** Standard (software-protected keys)
- **Soft delete:** 90 days
- **Purge protection:** Disabled (for easier dev)
- **Access policy:** RBAC (not legacy access policies)

**Cost:** ~$5/month (secrets only)

### Test Environment

```bicep
{
  "sku": {
    "family": "A",
    "name": "standard"
  },
  "properties": {
    "enableSoftDelete": true,
    "softDeleteRetentionInDays": 90,
    "enablePurgeProtection": true
  }
}
```

**Configuration:**
- **SKU:** Standard
- **Purge protection:** Enabled
- **Private endpoint:** Optional

**Cost:** ~$5/month

### Production Environment

```bicep
{
  "sku": {
    "family": "A",
    "name": "premium"  // HSM-backed keys
  },
  "properties": {
    "enableSoftDelete": true,
    "softDeleteRetentionInDays": 90,
    "enablePurgeProtection": true,
    "networkAcls": {
      "defaultAction": "Deny",
      "bypass": "AzureServices",
      "virtualNetworkRules": []
    }
  }
}
```

**Configuration:**
- **SKU:** Premium (HSM-backed keys for TDE, encryption)
- **Soft delete:** 90 days
- **Purge protection:** Enabled
- **Private endpoint:** Required
- **Network:** Deny public access

**Cost:** ~$15/month (Premium tier + secret operations)

---

## Virtual Network

### Dev Environment

```bicep
{
  "addressSpace": {
    "addressPrefixes": ["10.0.0.0/16"]
  },
  "subnets": [
    {
      "name": "function-apps-subnet",
      "addressPrefix": "10.0.1.0/24",
      "delegations": [
        {
          "serviceName": "Microsoft.Web/serverFarms"
        }
      ]
    },
    {
      "name": "private-endpoints-subnet",
      "addressPrefix": "10.0.2.0/24",
      "privateEndpointNetworkPolicies": "Disabled"
    }
  ]
}
```

**Configuration:**
- **Address space:** 10.0.0.0/16 (65,536 IPs)
- **Subnets:**
  - function-apps-subnet: 10.0.1.0/24 (256 IPs)
  - private-endpoints-subnet: 10.0.2.0/24 (256 IPs)
  - adf-managed-subnet: 10.0.3.0/24 (256 IPs)
- **DDoS protection:** Basic (free)
- **NSGs:** Attached to each subnet

**Cost:** Free (except data transfer)

### Test Environment

```bicep
{
  "addressSpace": {
    "addressPrefixes": ["10.1.0.0/16"]
  }
  // Same subnet structure as dev with 10.1.x.x
}
```

**Configuration:**
- **Address space:** 10.1.0.0/16
- Same subnets, different IP ranges

### Production Environment

```bicep
{
  "addressSpace": {
    "addressPrefixes": ["10.2.0.0/16"]
  },
  "enableDdosProtection": true,  // Consider standard DDoS if budget allows
  "subnets": [
    // Same as dev/test with 10.2.x.x
    {
      "name": "app-gateway-subnet",
      "addressPrefix": "10.2.4.0/24"  // For future API Management
    }
  ]
}
```

**Configuration:**
- **Address space:** 10.2.0.0/16
- **DDoS protection:** Standard (optional, +$3,000/month)
- **Additional subnet:** For Application Gateway / API Management

**Cost:** $0 (Standard DDoS if enabled: $3,000/month)

---

## Application Insights & Log Analytics

### All Environments

```bicep
{
  "properties": {
    "Application_Type": "web",
    "RetentionInDays": 30,  // Dev/Test
    "IngestionMode": "LogAnalytics",
    "publicNetworkAccessForIngestion": "Enabled",
    "publicNetworkAccessForQuery": "Enabled"
  }
}
```

**Configuration:**
- **Retention:**
  - Dev: 30 days
  - Test: 30 days
  - Prod: 90 days
- **Sampling:** Adaptive (default)
- **Daily cap:** 5 GB/day (dev/test), 20 GB/day (prod)

**Cost:**
- **Dev:** ~$30/month (2 GB/day ingestion)
- **Test:** ~$50/month (3 GB/day)
- **Prod:** ~$300/month (15 GB/day, 90 day retention)

---

## Summary Cost Estimates

| Environment | Monthly Cost | Annual Cost |
|------------|-------------|------------|
| **Dev** | ~$455 | ~$5,460 |
| **Test** | ~$915 | ~$10,980 |
| **Prod** | ~$4,865 | ~$58,380 |
| **Total** | ~$6,235 | ~$74,820 |

**Cost Breakdown (Production):**
- Azure Functions (EP2): $600-2,000
- Storage Accounts (GRS): $400
- Service Bus (Premium): $650
- SQL Database (Elastic Pool): $1,800
- Application Insights: $300
- ADF: $200
- Key Vault (Premium): $15
- Other (networking, etc.): $100

**Cost Optimization Opportunities:**
1. Use Azure Reservations (1-year or 3-year) for 30-40% savings
2. Implement auto-shutdown in dev/test environments
3. Use Storage lifecycle management aggressively
4. Review Application Insights sampling settings
5. Consider SQL Elastic Pools for better utilization
6. Use Azure Hybrid Benefit if applicable

---

## Scaling Strategies

### Horizontal Scaling (Scale Out)

**Triggers:**
- CPU > 70%
- Memory > 80%
- Queue depth > 100 messages
- Request count > 1000/min

**Limits:**
- Dev: Max 3 instances
- Test: Max 5 instances
- Prod: Max 30 instances

### Vertical Scaling (Scale Up)

**When to scale up:**
- Consistently hitting max scale-out limits
- Individual function duration increasing
- Memory pressure observed

**Next tier options:**
- EP1 → EP2 (double capacity)
- EP2 → EP3 (double again)

### Database Scaling

**When to scale SQL:**
- DTU utilization > 80%
- Query performance degradation
- Blocking detected

**Scale path:**
- Basic → S0/S1 → S2 → S3
- Or move to Premium tier for better performance
- Or move to Elastic Pool for cost efficiency

---

## Monitoring Thresholds

| Metric | Dev | Test | Prod |
|--------|-----|------|------|
| CPU Utilization | >90% | >85% | >70% |
| Memory Utilization | >95% | >90% | >80% |
| Queue Depth | >500 | >300 | >100 |
| Function Duration | >30s | >15s | >5s |
| Error Rate | >10% | >5% | >2% |
| SQL DTU | >95% | >90% | >80% |
| Storage Throttling | Any | Any | Any |

---

## Next Steps

1. Review this sizing guide with finance team for budget approval
2. Adjust SKUs based on projected transaction volume
3. Implement auto-scaling rules in Bicep templates
4. Set up cost alerts in Azure Cost Management
5. Monitor actual usage and right-size after 30 days
6. Document any deviations from this guide

---

**Last Reviewed:** October 5, 2025  
**Next Review:** November 5, 2025  
**Approved By:** Platform Lead
