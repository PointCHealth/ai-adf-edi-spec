# AI Prompt: Create Monitoring Dashboards

## Objective

Create comprehensive Azure Workbooks (dashboards) in Application Insights for monitoring the EDI platform's health, performance, and business metrics.

## Prerequisites

- Application Insights deployed and configured
- Azure Functions deployed and logging to Application Insights
- Log Analytics workspace connected
- Understanding of KQL (Kusto Query Language)

## Prompt

```text
I need you to create comprehensive monitoring dashboards using Azure Workbooks for the Healthcare EDI Platform.

Context:
- Platform: Azure Functions, Service Bus, Storage, ADF
- Monitoring: Application Insights + Log Analytics
- Compliance: HIPAA - need audit trail visibility
- Users: Operations team, platform engineers, business stakeholders
- SLA: 99.5% availability, <5 min processing time

Please create these Azure Workbook templates:

---

## Dashboard 1: Executive Summary Dashboard

**File:** `monitoring/workbooks/executive-summary.workbook`

Purpose: High-level KPIs for leadership and business stakeholders

Sections:

### 1. Health Status (Traffic Light)
- Overall platform health (Green/Yellow/Red)
- Based on: Error rate, availability, SLA compliance
- Large visual indicator at top

### 2. Transaction Volume (Last 24 Hours)
```kql
requests
| where timestamp > ago(24h)
| where cloud_RoleName has "edi-"
| summarize Count=count() by bin(timestamp, 1h), name
| render timechart
```

### 3. Key Metrics (Cards)
- Total transactions processed today
- Current processing rate (transactions/hour)
- Average processing time
- Error rate (%)
- Partners active today
- Files in queue

### 4. SLA Compliance (Gauge)
- % of transactions meeting SLA (<5 min)
- Uptime percentage
- Acknowledgment timeliness

### 5. Top Partners by Volume (Bar Chart)
```kql
customEvents
| where timestamp > ago(24h)
| where name == "TransactionProcessed"
| extend partnerId = tostring(customDimensions.partnerId)
| summarize Count=count() by partnerId
| top 10 by Count desc
| render barchart
```

### 6. Transaction Status Distribution (Pie Chart)
- Successful
- In Progress
- Failed
- Quarantined

---

## Dashboard 2: Operations Dashboard

**File:** `monitoring/workbooks/operations.workbook`

Purpose: Real-time monitoring for on-call engineers

Sections:

### 1. Active Alerts
- List of currently firing alerts
- Severity, resource, time fired
- Link to investigation runbook

### 2. Error Timeline (Last 4 Hours)
```kql
exceptions
| where timestamp > ago(4h)
| where cloud_RoleName has "edi-"
| summarize Count=count() by bin(timestamp, 5m), cloud_RoleName
| render timechart
```

### 3. Function Health Status
- Table showing each Azure Function
- Columns: Name, Status, Last Success, Error Count, Avg Duration
- Color-coded by health

### 4. Queue Depths
```kql
customMetrics
| where timestamp > ago(15m)
| where name == "QueueDepth"
| extend queue = tostring(customDimensions.queueName)
| summarize CurrentDepth=max(value) by queue
| where CurrentDepth > 0
```

### 5. Dead Letter Queue Messages
- Alert if DLQ has messages
- Link to investigate messages
- Auto-refresh every 1 minute

### 6. Slow Requests (>5s)
```kql
requests
| where timestamp > ago(1h)
| where duration > 5000
| project timestamp, name, duration, resultCode, cloud_RoleName
| order by duration desc
| take 20
```

### 7. Failed Dependencies
- Storage, Service Bus, SQL connection failures
- Retry attempts and outcomes

### 8. Recent Deployments
- Track deployments and correlate with errors
- Show deployment time, version, environment

---

## Dashboard 3: Performance Dashboard

**File:** `monitoring/workbooks/performance.workbook`

Purpose: Performance analysis and optimization

Sections:

### 1. Response Time Percentiles
```kql
requests
| where timestamp > ago(24h)
| summarize 
    p50=percentile(duration, 50),
    p90=percentile(duration, 90),
    p95=percentile(duration, 95),
    p99=percentile(duration, 99)
    by bin(timestamp, 1h), name
| render timechart
```

### 2. Function Execution Duration by Transaction Type
- Box plot showing distribution
- Identify outliers
- Compare across functions

### 3. Throughput Analysis
- Requests per second over time
- Group by function
- Compare to capacity limits

### 4. Resource Utilization
- CPU usage (if available from host metrics)
- Memory usage
- Function instance count

### 5. Dependency Performance
```kql
dependencies
| where timestamp > ago(24h)
| summarize 
    AvgDuration=avg(duration),
    MaxDuration=max(duration),
    FailureRate=100.0*countif(success == false)/count()
    by target, type
| order by AvgDuration desc
```

### 6. Storage Operations
- Blob read/write performance
- Queue enqueue/dequeue latency
- Identify slow storage calls

### 7. Function Cold Start Analysis
- Identify cold starts
- Duration of cold starts
- Frequency by function

---

## Dashboard 4: Business Intelligence Dashboard

**File:** `monitoring/workbooks/business-intelligence.workbook`

Purpose: Business metrics and analytics

Sections:

### 1. Transaction Volume Trends (30 Days)
```kql
customEvents
| where timestamp > ago(30d)
| where name == "TransactionProcessed"
| extend transactionType = tostring(customDimensions.transactionType)
| summarize Count=count() by bin(timestamp, 1d), transactionType
| render timechart
```

### 2. Partner Activity Matrix
- Heatmap showing transactions per partner per day
- Identify inactive partners
- Spot unusual patterns

### 3. Transaction Type Breakdown
- 270 (Eligibility) vs 834 (Enrollment) vs 837 (Claims) volumes
- Trends over time
- Compare to historical averages

### 4. Processing Time by Partner
- Average, min, max processing time
- Identify partners with performance issues
- SLA compliance by partner

### 5. File Size Analysis
- Distribution of file sizes
- Correlation with processing time
- Identify large file issues

### 6. Error Analysis by Partner
- Error rate per partner
- Common error types
- Trend over time

### 7. Cost Allocation (if cost data available)
- Estimated cost per partner
- Cost per transaction
- Trend analysis

---

## Dashboard 5: Security & Audit Dashboard

**File:** `monitoring/workbooks/security-audit.workbook`

Purpose: Compliance and security monitoring

Sections:

### 1. Authentication Events
```kql
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where Category == "Authentication"
| summarize Count=count() by ResultType, identity_claim_http_schemas_xmlsoap_org_ws_2005_05_identity_claims_upn_s
| order by Count desc
```

### 2. Access Logs
- Who accessed what resources
- Failed access attempts
- Unusual access patterns

### 3. Data Access Audit Trail
- File access logs
- Partner data access
- Export/download activities

### 4. Configuration Changes
- Changes to partner configurations
- Infrastructure modifications
- Security setting updates

### 5. Failed Authentication Attempts
- Source IP addresses
- User accounts attempted
- Frequency and patterns

### 6. Compliance Checklist Status
- Encryption status
- Backup completion
- Audit log retention
- Certificate expiration warnings

---

## Common Requirements for ALL Dashboards

1. **Parameters:**
   - Time range selector (default: 24 hours)
   - Environment filter (dev/test/prod)
   - Partner filter (optional)
   - Transaction type filter (optional)

2. **Auto-Refresh:**
   - Executive/Business dashboards: 5 minutes
   - Operations dashboard: 1 minute
   - Performance dashboard: 2 minutes
   - Security dashboard: 5 minutes

3. **Export Capabilities:**
   - Export to PDF for reports
   - Export to Excel for analysis
   - Scheduled email delivery (via Power Automate)

4. **Links and Actions:**
   - Click to drill down to detailed logs
   - Link to runbooks for common issues
   - Link to Azure Portal resources
   - Link to GitHub for recent deployments

5. **Responsive Design:**
   - Mobile-friendly layout
   - Adjust based on screen size
   - Collapsible sections

Also provide:
1. ARM/Bicep template to deploy all workbooks
2. PowerShell script to import workbooks
3. Documentation on how to customize workbooks
4. KQL query library with all queries used
5. Screenshots or mockups of each dashboard layout
```

## Expected Outcome

After running this prompt, you should have:

- ✅ 5 comprehensive Azure Workbook templates
- ✅ KQL queries for all metrics
- ✅ Deployment scripts (ARM/Bicep)
- ✅ Dashboard documentation
- ✅ Customization guide

## Validation Steps

1. Deploy workbooks to dev environment:

   ```powershell
   # Using Azure CLI
   az monitor app-insights workbook create \
     --resource-group rg-edi-dev-eastus2 \
     --name "EDI Executive Summary" \
     --category workbook \
     --serialized-data @monitoring/workbooks/executive-summary.json
   ```

2. Test each dashboard:
   - Navigate to Application Insights → Workbooks
   - Open each workbook
   - Verify all visualizations render correctly
   - Test time range selector
   - Test filters

3. Verify data accuracy:
   - Compare dashboard metrics with raw query results
   - Validate calculations
   - Check for missing data

4. Test on mobile device:
   - Open workbooks on phone/tablet
   - Verify responsive layout

5. Schedule email delivery (optional):
   ```powershell
   # Set up Logic App to export and email workbook
   # Or use Power Automate scheduled flow
   ```

## Troubleshooting

**Workbook shows no data:**

- Verify Application Insights is receiving telemetry
- Check time range selector
- Ensure environment filter matches actual environment tags
- Validate KQL query syntax

**Queries timeout:**

- Reduce time range
- Add sampling to queries
- Optimize KQL (use summarize earlier)
- Consider pre-aggregated tables

**Visualizations not rendering:**

- Check browser console for errors
- Verify JSON schema is valid
- Test query in Log Analytics first
- Clear browser cache

**Incorrect metrics:**

- Verify custom event/metric names match code
- Check customDimensions property names
- Validate data types in queries
- Review Application Insights sampling settings

## Integration with Alerts

Link dashboards to alert rules:

```bicep
resource metricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'high-error-rate'
  location: 'global'
  properties: {
    description: 'Alert when error rate exceeds 5%'
    severity: 2
    enabled: true
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ErrorRate'
          metricName: 'requests/failed'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}
```

## Next Steps

After successful completion:

- Share dashboard links with team
- Set up scheduled reports for stakeholders
- Create custom views for specific roles
- Integrate with Teams notifications [06-create-monitoring-workflows.md](06-create-monitoring-workflows.md)
- Document dashboard navigation in runbooks [17-create-operations-runbooks.md](17-create-operations-runbooks.md)
