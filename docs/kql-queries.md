# KQL Queries Library

**Purpose:** Standard Application Insights queries for monitoring the Healthcare EDI Platform  
**Last Updated:** 2025-10-05  
**Owner:** Platform Engineering Team

---

## Overview

This document contains reusable KQL (Kusto Query Language) queries for monitoring, troubleshooting, and reporting on the EDI platform. These queries are used in Azure Workbooks dashboards and can be run directly in Application Insights Analytics.

---

## Table of Contents

1. [Executive Metrics](#executive-metrics)
2. [Transaction Processing](#transaction-processing)
3. [Performance Monitoring](#performance-monitoring)
4. [Error Analysis](#error-analysis)
5. [Partner Activity](#partner-activity)
6. [Service Bus Metrics](#service-bus-metrics)
7. [Storage Operations](#storage-operations)
8. [Function Health](#function-health)

---

## Executive Metrics

### Daily Transaction Volume

```kql
// Total transactions processed per day by type
customMetrics
| where name == "InboundRouter.FilesProcessed"
| extend transactionType = tostring(customDimensions.transactionType)
| extend partnerId = tostring(customDimensions.partnerId)
| summarize count() by transactionType, bin(timestamp, 1d)
| render columnchart
```

### Success Rate (Last 24 Hours)

```kql
// Overall platform success rate
requests
| where timestamp > ago(24h)
| summarize 
    total = count(),
    successful = countif(success == true),
    failed = countif(success == false)
| extend successRate = round(successful * 100.0 / total, 2)
| project successRate, total, successful, failed
```

### SLA Compliance

```kql
// Percentage of transactions processed within SLA (< 5 minutes end-to-end)
let slaThreshold = 5m;
traces
| where message contains "TransactionCompleted"
| extend 
    startTime = todatetime(customDimensions.startTime),
    endTime = todatetime(customDimensions.endTime),
    transactionType = tostring(customDimensions.transactionType)
| extend duration = endTime - startTime
| summarize 
    total = count(),
    withinSLA = countif(duration <= slaThreshold)
| extend slaCompliance = round(withinSLA * 100.0 / total, 2)
| project slaCompliance, total, withinSLA
```

---

## Transaction Processing

### Transactions by Type and Partner

```kql
// Breakdown of transaction volume by type and partner
customMetrics
| where name == "InboundRouter.FilesProcessed"
| extend 
    transactionType = tostring(customDimensions.transactionType),
    partnerId = tostring(customDimensions.partnerId)
| summarize count() by transactionType, partnerId
| order by count_ desc
```

### Hourly Transaction Trend

```kql
// Transaction volume by hour (for capacity planning)
customMetrics
| where name == "InboundRouter.FilesProcessed"
| extend transactionType = tostring(customDimensions.transactionType)
| summarize count() by transactionType, bin(timestamp, 1h)
| render timechart
```

### Transaction Flow Timeline

```kql
// Track a specific transaction through all stages
let correlationId = "your-correlation-id-here";
union traces, requests, dependencies
| where operation_Id == correlationId or customDimensions.correlationId == correlationId
| project 
    timestamp,
    itemType,
    name,
    message,
    duration = coalesce(duration, 0.0),
    success,
    cloud_RoleName
| order by timestamp asc
```

### Top Transaction Paths

```kql
// Most common processing paths through the system
traces
| where message contains "ProcessingStage"
| extend 
    stage = tostring(customDimensions.stage),
    transactionType = tostring(customDimensions.transactionType)
| summarize count() by stage, transactionType
| order by count_ desc
| take 20
```

---

## Performance Monitoring

### P50/P95/P99 Latency by Function

```kql
// Latency percentiles for each function
requests
| where timestamp > ago(24h)
| extend functionName = cloud_RoleName
| summarize 
    p50 = percentile(duration, 50),
    p95 = percentile(duration, 95),
    p99 = percentile(duration, 99),
    avg = avg(duration),
    max = max(duration)
  by functionName
| order by p95 desc
```

### Routing Duration Over Time

```kql
// InboundRouter latency trend
customMetrics
| where name == "InboundRouter.RoutingDuration"
| summarize 
    avg_duration = avg(value),
    p95_duration = percentile(value, 95)
  by bin(timestamp, 5m)
| render timechart
```

### Mapper Processing Time

```kql
// Time spent in mapping functions by transaction type
requests
| where cloud_RoleName contains "mapper"
| extend transactionType = tostring(customDimensions.transactionType)
| summarize 
    avg_duration_ms = avg(duration),
    p95_duration_ms = percentile(duration, 95)
  by cloud_RoleName, transactionType
| order by p95_duration_ms desc
```

### Slow Transactions (> 10 seconds)

```kql
// Identify slow processing transactions
requests
| where duration > 10000 // milliseconds
| extend 
    partnerId = tostring(customDimensions.partnerId),
    transactionType = tostring(customDimensions.transactionType),
    fileSize = tolong(customDimensions.fileSize)
| project 
    timestamp,
    cloud_RoleName,
    name,
    duration,
    partnerId,
    transactionType,
    fileSize,
    operation_Id
| order by duration desc
| take 50
```

---

## Error Analysis

### Error Rate by Function

```kql
// Error percentage by function over last 24 hours
requests
| where timestamp > ago(24h)
| summarize 
    total = count(),
    errors = countif(success == false)
  by cloud_RoleName
| extend errorRate = round(errors * 100.0 / total, 2)
| order by errorRate desc
```

### Top Error Messages

```kql
// Most common errors across the platform
exceptions
| where timestamp > ago(24h)
| extend errorMessage = tostring(parse_json(details)[0].message)
| summarize count() by errorMessage, cloud_RoleName
| order by count_ desc
| take 20
```

### Parsing Errors by Transaction Type

```kql
// X12 parsing failures by transaction type
traces
| where message contains "ParsingError" or message contains "ValidationError"
| extend 
    transactionType = tostring(customDimensions.transactionType),
    errorType = tostring(customDimensions.errorType),
    partnerId = tostring(customDimensions.partnerId)
| summarize count() by transactionType, errorType, partnerId
| order by count_ desc
```

### Error Timeline

```kql
// Visualize error spikes
requests
| where success == false
| summarize errorCount = count() by bin(timestamp, 5m), cloud_RoleName
| render timechart
```

### Dead Letter Queue Messages

```kql
// Service Bus messages sent to dead letter queue
traces
| where message contains "DeadLetter"
| extend 
    queueName = tostring(customDimensions.queueName),
    reason = tostring(customDimensions.deadLetterReason),
    partnerId = tostring(customDimensions.partnerId)
| summarize count() by queueName, reason
| order by count_ desc
```

---

## Partner Activity

### Transactions by Partner

```kql
// Volume per trading partner
customMetrics
| where name == "InboundRouter.FilesProcessed"
| extend partnerId = tostring(customDimensions.partnerId)
| summarize count() by partnerId, bin(timestamp, 1d)
| render columnchart
```

### Partner Error Rates

```kql
// Error rate by partner to identify problematic partners
requests
| where timestamp > ago(7d)
| extend partnerId = tostring(customDimensions.partnerId)
| where isnotempty(partnerId)
| summarize 
    total = count(),
    errors = countif(success == false)
  by partnerId
| extend errorRate = round(errors * 100.0 / total, 2)
| where errorRate > 1.0 // Only show partners with > 1% error rate
| order by errorRate desc
```

### Partner File Sizes

```kql
// Average and max file sizes per partner
customMetrics
| where name == "InboundRouter.FileSize"
| extend 
    partnerId = tostring(customDimensions.partnerId),
    fileSizeBytes = tolong(value)
| summarize 
    avgSizeKB = round(avg(fileSizeBytes) / 1024, 2),
    maxSizeKB = round(max(fileSizeBytes) / 1024, 2),
    fileCount = count()
  by partnerId
| order by avgSizeKB desc
```

### Inactive Partners

```kql
// Partners that haven't sent files in 7 days
let recentPartners = customMetrics
    | where timestamp > ago(7d)
    | where name == "InboundRouter.FilesProcessed"
    | extend partnerId = tostring(customDimensions.partnerId)
    | distinct partnerId;
let allPartners = customMetrics
    | where timestamp > ago(30d)
    | where name == "InboundRouter.FilesProcessed"
    | extend partnerId = tostring(customDimensions.partnerId)
    | distinct partnerId;
allPartners
| where partnerId !in (recentPartners)
| project partnerId, status = "Inactive (7+ days)"
```

---

## Service Bus Metrics

### Queue Depth by Queue

```kql
// Active message count in each queue
customMetrics
| where name == "ServiceBus.QueueDepth"
| extend queueName = tostring(customDimensions.queueName)
| summarize avgDepth = avg(value), maxDepth = max(value) by queueName, bin(timestamp, 5m)
| render timechart
```

### Message Processing Rate

```kql
// Messages processed per minute by queue
traces
| where message contains "MessageCompleted"
| extend queueName = tostring(customDimensions.queueName)
| summarize messagesPerMinute = count() by queueName, bin(timestamp, 1m)
| render timechart
```

### Message Age in Queue

```kql
// How long messages wait before processing
customMetrics
| where name == "ServiceBus.MessageAge"
| extend queueName = tostring(customDimensions.queueName)
| summarize 
    avgAgeSeconds = avg(value),
    p95AgeSeconds = percentile(value, 95)
  by queueName
| order by p95AgeSeconds desc
```

---

## Storage Operations

### Blob Uploads by Container

```kql
// File uploads to storage by container
dependencies
| where type == "Azure blob"
| where name contains "PutBlob" or name contains "Upload"
| extend container = extract(@"\/([^\/]+)\/", 1, data)
| summarize count() by container, bin(timestamp, 1h)
| render columnchart
```

### Storage Throughput

```kql
// Total bytes uploaded/downloaded
customMetrics
| where name == "Storage.BytesTransferred"
| extend 
    operation = tostring(customDimensions.operation),
    bytesTransferred = tolong(value)
| summarize totalGB = sum(bytesTransferred) / 1024 / 1024 / 1024 by operation, bin(timestamp, 1h)
| render timechart
```

### Storage Latency

```kql
// Average storage operation latency
dependencies
| where type == "Azure blob"
| summarize 
    avgLatency = avg(duration),
    p95Latency = percentile(duration, 95)
  by name
| order by p95Latency desc
```

---

## Function Health

### Function Availability

```kql
// Percentage uptime per function
requests
| where timestamp > ago(24h)
| summarize 
    total = count(),
    successful = countif(success == true)
  by cloud_RoleName
| extend availability = round(successful * 100.0 / total, 2)
| project cloud_RoleName, availability, total
| order by availability asc
```

### Function Execution Count

```kql
// Number of executions per function
requests
| where timestamp > ago(24h)
| summarize executionCount = count() by cloud_RoleName, bin(timestamp, 1h)
| render timechart
```

### Function Cold Starts

```kql
// Identify cold start latency
requests
| where timestamp > ago(24h)
| where duration > 5000 // Likely cold start if > 5 seconds
| extend isColdStart = customDimensions.coldStart == "true"
| summarize coldStarts = countif(isColdStart == true) by cloud_RoleName
| order by coldStarts desc
```

### Function Scaling Instances

```kql
// Number of active function instances over time
customMetrics
| where name == "FunctionApp.InstanceCount"
| extend functionName = tostring(customDimensions.functionName)
| summarize avgInstances = avg(value), maxInstances = max(value) by functionName, bin(timestamp, 5m)
| render timechart
```

---

## Alerting Queries

### High Error Rate Alert

```kql
// Alert when error rate exceeds 5% in 15 minutes
requests
| where timestamp > ago(15m)
| summarize 
    total = count(),
    errors = countif(success == false)
| extend errorRate = errors * 100.0 / total
| where errorRate > 5.0
| project errorRate, total, errors
```

### SLA Breach Alert

```kql
// Alert when P95 latency exceeds 10 seconds
requests
| where timestamp > ago(15m)
| summarize p95Latency = percentile(duration, 95)
| where p95Latency > 10000
| project p95Latency
```

### Queue Backlog Alert

```kql
// Alert when any queue has > 100 messages for 30 minutes
customMetrics
| where name == "ServiceBus.QueueDepth"
| where timestamp > ago(30m)
| extend queueName = tostring(customDimensions.queueName)
| summarize avgDepth = avg(value) by queueName
| where avgDepth > 100
| project queueName, avgDepth
```

---

## Business Intelligence Queries

### Daily Revenue Impact (Transaction Count * Value)

```kql
// Estimate business value (assumes $2 per transaction)
customMetrics
| where name == "InboundRouter.FilesProcessed"
| extend transactionType = tostring(customDimensions.transactionType)
| summarize transactionCount = count() by bin(timestamp, 1d), transactionType
| extend estimatedRevenue = transactionCount * 2.0
| project timestamp, transactionType, transactionCount, estimatedRevenue
| render columnchart
```

### Partner Transaction Value

```kql
// Revenue contribution by partner
customMetrics
| where name == "InboundRouter.FilesProcessed"
| extend partnerId = tostring(customDimensions.partnerId)
| summarize transactionCount = count() by partnerId
| extend estimatedRevenue = transactionCount * 2.0
| order by estimatedRevenue desc
```

---

## Troubleshooting Queries

### Find Transaction by Member ID

```kql
// Locate all logs for a specific member
let memberId = "M123456789";
union traces, requests, exceptions
| where message contains memberId or customDimensions contains memberId
| project 
    timestamp,
    itemType,
    cloud_RoleName,
    message,
    operation_Id
| order by timestamp asc
```

### Find Transaction by File Name

```kql
// Track processing of a specific file
let fileName = "270_20251005_001.x12";
traces
| where message contains fileName
| project 
    timestamp,
    cloud_RoleName,
    message,
    severityLevel,
    operation_Id
| order by timestamp asc
```

### Failed Retries

```kql
// Identify transactions that failed after multiple retries
traces
| where message contains "RetryAttempt"
| extend retryCount = toint(customDimensions.retryCount)
| where retryCount >= 3
| summarize maxRetries = max(retryCount) by operation_Id, cloud_RoleName
| order by maxRetries desc
```

---

## Usage Instructions

### Running Queries in Azure Portal

1. Navigate to Application Insights → Logs
2. Copy query from this document
3. Replace parameters (e.g., `correlationId`, `memberId`) with actual values
4. Click "Run"

### Using Queries in Workbooks

1. Create new Workbook or edit existing
2. Add "Logs" step
3. Paste query
4. Add parameters for interactive filtering
5. Choose visualization (table, chart, etc.)

### Scheduling Queries as Alerts

1. Navigate to Application Insights → Alerts
2. Create "New alert rule"
3. Condition: "Custom log search"
4. Paste alert query
5. Configure threshold and action group

---

**Last Updated:** 2025-10-05  
**Maintained By:** Platform Engineering Team  
**Review Schedule:** Quarterly
