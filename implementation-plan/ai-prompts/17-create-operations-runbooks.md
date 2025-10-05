# AI Prompt: Create Operations Runbooks

## Objective

Create comprehensive operational runbooks documenting troubleshooting procedures, incident response, and routine maintenance tasks for the EDI platform.

## Prerequisites

- Azure resources deployed
- Monitoring dashboards created
- Alert rules configured
- Team familiar with platform architecture

## Prompt

```text
I need you to create operational runbooks for the Healthcare EDI Platform to guide the operations team through common scenarios.

Context:
- Platform: Azure Functions, Service Bus, Storage, ADF, SQL
- Monitoring: Application Insights, Log Analytics
- On-Call: 24/7 support for production
- Compliance: HIPAA - all actions must be auditable
- Team: DevOps/Platform Engineering team

Please create these runbook documents:

---

## Runbook 1: Incident Response Procedure

**File:** `docs/runbooks/01-incident-response.md`

Purpose: Guide for responding to production incidents

Contents:

### Severity Definitions

**Severity 1 (Critical):**
- Platform down or unavailable
- Data loss or corruption
- HIPAA breach suspected
- Response: Immediate (page on-call)
- Resolution Target: 1 hour

**Severity 2 (High):**
- Degraded performance (>20% slower)
- Single function failure
- Partner unable to send/receive files
- Response: Within 30 minutes
- Resolution Target: 4 hours

**Severity 3 (Medium):**
- Minor errors not affecting operations
- Performance degradation (<20%)
- Non-critical feature unavailable
- Response: Next business day
- Resolution Target: 24 hours

### Incident Response Steps

1. **Acknowledge Alert**
   - In PagerDuty/Teams, acknowledge alert
   - Note time of acknowledgment
   - Assess severity

2. **Initial Investigation**
   - Check Operations Dashboard: [link]
   - Review error timeline in Application Insights
   - Check Azure Service Health: https://status.azure.com
   - Identify affected resources and partners

3. **Communication**
   - Post incident in Teams #edi-incidents channel
   - Notify stakeholders if Severity 1 or 2
   - Update status page (if applicable)

4. **Mitigation**
   - Follow specific troubleshooting runbook (see below)
   - Document all actions taken
   - Capture screenshots/logs

5. **Resolution**
   - Verify fix with synthetic transaction
   - Monitor for 15 minutes
   - Confirm with affected partners

6. **Post-Incident**
   - Create incident report
   - Schedule post-mortem (Severity 1 & 2)
   - Update runbooks with learnings

### Escalation Path

1. On-call engineer (primary)
2. Platform lead (if no resolution in 30 min)
3. CTO (for Severity 1 only)

---

## Runbook 2: Function Failure Troubleshooting

**File:** `docs/runbooks/02-function-failure-troubleshooting.md`

Purpose: Diagnose and resolve Azure Function failures

### Symptoms
- Function returning 500 errors
- Function not processing messages
- Function timing out

### Diagnostic Steps

**Step 1: Check Function Status**
```powershell
# Check if function is running
az functionapp show \
  --name func-edi-inbound-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --query state

# Expected: "Running"
```

**Step 2: Review Recent Errors**
```kql
// In Application Insights
exceptions
| where timestamp > ago(1h)
| where cloud_RoleName == "func-edi-inbound-prod-eastus2"
| project timestamp, problemId, outerMessage, innermostMessage
| order by timestamp desc
| take 50
```

**Step 3: Check Dependencies**
- Storage account accessible?
- Service Bus connection working?
- SQL database responsive?
- Key Vault secrets accessible?

**Step 4: Check Configuration**
```powershell
# List application settings
az functionapp config appsettings list \
  --name func-edi-inbound-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2
```

**Step 5: Check Deployment History**
```powershell
# Check recent deployments
az functionapp deployment list-publishing-profiles \
  --name func-edi-inbound-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2
```

### Common Issues and Fixes

**Issue: Function returning 401 Unauthorized**
- Cause: Managed identity missing permissions
- Fix:
  ```powershell
  # Grant Key Vault access
  az keyvault set-policy \
    --name kv-edi-prod-eastus2 \
    --object-id $(az functionapp identity show --name func-edi-inbound-prod-eastus2 --resource-group rg-edi-prod-eastus2 --query principalId -o tsv) \
    --secret-permissions get list
  ```

**Issue: Function timing out**
- Cause: Long-running operation or external API slow
- Fix: Check timeout setting, implement async pattern
  ```powershell
  # Increase timeout (max 10 minutes for Consumption)
  az functionapp config set \
    --name func-edi-inbound-prod-eastus2 \
    --resource-group rg-edi-prod-eastus2 \
    --timeout 600
  ```

**Issue: Function not triggered**
- Cause: Service Bus connection or trigger binding issue
- Fix: Restart function app
  ```powershell
  az functionapp restart \
    --name func-edi-inbound-prod-eastus2 \
    --resource-group rg-edi-prod-eastus2
  ```

### Rollback Procedure

If recent deployment caused issues:

```powershell
# List deployment slots
az functionapp deployment slot list \
  --name func-edi-inbound-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2

# Swap staging back to production (rollback)
az functionapp deployment slot swap \
  --name func-edi-inbound-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --slot staging
```

---

## Runbook 3: Service Bus Issues

**File:** `docs/runbooks/03-service-bus-troubleshooting.md`

Purpose: Resolve Service Bus connectivity and messaging issues

### Symptoms
- Messages stuck in queue
- Dead-letter queue has messages
- Connection failures

### Diagnostic Steps

**Step 1: Check Service Bus Health**
```powershell
# Check namespace status
az servicebus namespace show \
  --name sb-edi-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --query status

# Check queue metrics
az servicebus queue show \
  --namespace-name sb-edi-prod-eastus2 \
  --name inbound-router-queue \
  --resource-group rg-edi-prod-eastus2 \
  --query "countDetails"
```

**Step 2: Review Dead-Letter Queue**
```kql
// In Application Insights
customEvents
| where timestamp > ago(4h)
| where name == "MessageDeadLettered"
| extend queueName = tostring(customDimensions.queueName)
| extend reason = tostring(customDimensions.deadLetterReason)
| summarize count() by queueName, reason
```

**Step 3: Check Connection Strings**
- Verify connection string in Key Vault
- Check managed identity permissions
- Test connection manually

### Common Issues and Fixes

**Issue: Messages in Dead-Letter Queue**

1. Investigate reason:
   ```powershell
   # Peek dead-letter messages
   az servicebus queue dead-letter peek \
     --namespace-name sb-edi-prod-eastus2 \
     --name inbound-router-queue \
     --resource-group rg-edi-prod-eastus2
   ```

2. Common reasons:
   - **MaxDeliveryCount exceeded:** Message failed processing 10 times
     - Action: Fix code bug, then resubmit message
   - **MessageLockLost:** Processing took too long
     - Action: Increase lock duration or optimize processing
   - **SessionLockLost:** Session processing timed out
     - Action: Review session handling logic

3. Resubmit messages:
   ```csharp
   // Use Service Bus Explorer tool or custom script
   // Manually inspect and resubmit valid messages
   ```

**Issue: Queue Depth Growing**

- Cause: Consumer not keeping up with producer
- Fix: Scale function app or increase concurrency
  ```powershell
  # Increase function app instances
  az functionapp plan update \
    --name plan-edi-prod-eastus2 \
    --resource-group rg-edi-prod-eastus2 \
    --max-burst 20
  ```

**Issue: Connection Failures**

- Check firewall rules
- Verify private endpoint configuration
- Check NSG rules

---

## Runbook 4: Storage Issues

**File:** `docs/runbooks/04-storage-troubleshooting.md`

Purpose: Resolve Azure Storage access and performance issues

### Symptoms
- File upload failures
- Slow blob operations
- Authentication errors

### Diagnostic Steps

**Step 1: Check Storage Account Health**
```powershell
# Check availability
az storage account show \
  --name stediprodeastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --query "primaryEndpoints"

# Check metrics
az monitor metrics list \
  --resource /subscriptions/{sub-id}/resourceGroups/rg-edi-prod-eastus2/providers/Microsoft.Storage/storageAccounts/stediprodeastus2 \
  --metric "Availability" \
  --start-time 2025-10-05T00:00:00Z \
  --end-time 2025-10-05T23:59:59Z
```

**Step 2: Test Access**
```powershell
# List containers
az storage container list \
  --account-name stediprodeastus2 \
  --auth-mode login

# Upload test file
echo "test" > test.txt
az storage blob upload \
  --account-name stediprodeastus2 \
  --container-name inbound \
  --name test.txt \
  --file test.txt \
  --auth-mode login
```

**Step 3: Review Access Logs**
```kql
StorageBlobLogs
| where TimeGenerated > ago(1h)
| where StatusCode >= 400
| project TimeGenerated, Uri, StatusCode, StatusText, AuthenticationType
| order by TimeGenerated desc
```

### Common Issues and Fixes

**Issue: 403 Forbidden**
- Cause: Missing RBAC permissions or network restrictions
- Fix:
  ```powershell
  # Grant Storage Blob Data Contributor
  az role assignment create \
    --assignee $(az functionapp identity show --name func-edi-inbound-prod-eastus2 --resource-group rg-edi-prod-eastus2 --query principalId -o tsv) \
    --role "Storage Blob Data Contributor" \
    --scope /subscriptions/{sub-id}/resourceGroups/rg-edi-prod-eastus2/providers/Microsoft.Storage/storageAccounts/stediprodeastus2
  ```

**Issue: Throttling (503)**
- Cause: Exceeded storage account limits
- Fix: Implement retry logic, distribute load, or increase limits

**Issue: Soft-deleted blobs**
- Restore deleted files:
  ```powershell
  az storage blob undelete \
    --account-name stediprodeastus2 \
    --container-name inbound \
    --name deleted-file.edi
  ```

---

## Runbook 5: Partner Connectivity Issues

**File:** `docs/runbooks/05-partner-connectivity.md`

Purpose: Troubleshoot partner-specific connection and data issues

### Symptoms
- Partner cannot upload files via SFTP
- Files not arriving from partner
- Outbound files not delivered to partner

### Diagnostic Steps

**Step 1: Verify Partner Configuration**
```powershell
# Check partner config exists
az storage blob show \
  --account-name stediprodeastus2 \
  --container-name partner-configs \
  --name partners/{partnerId}/partner.json \
  --auth-mode login
```

**Step 2: Test SFTP Connection**
```powershell
# From Azure Cloud Shell or VM with network access
sftp username@stediprodeastus2.blob.core.windows.net
# Try to login and list files
```

**Step 3: Review Partner-Specific Logs**
```kql
customEvents
| where timestamp > ago(24h)
| extend partnerId = tostring(customDimensions.partnerId)
| where partnerId == "BCBS001"
| summarize count() by name, tostring(customDimensions.status)
```

### Common Issues and Fixes

**Issue: SFTP Authentication Failed**
- Cause: SSH key mismatch or account disabled
- Fix: Verify SSH public key in partner config matches their private key
- Regenerate credentials if needed

**Issue: Files Not Arriving**
- Check partner's outbound folder permissions
- Verify Event Grid subscription is active
- Check if files are quarantined

**Issue: Outbound Delivery Failed**
- Check partner's SFTP/API endpoint accessibility
- Verify credentials in Key Vault
- Review connector function logs

---

## Runbook 6: Routine Maintenance

**File:** `docs/runbooks/06-routine-maintenance.md`

Purpose: Regular maintenance tasks to keep platform healthy

### Daily Tasks (Automated)

- [ ] Check for Azure service health issues
- [ ] Review dead-letter queue counts
- [ ] Verify nightly backups completed
- [ ] Check drift detection results

### Weekly Tasks (Manual)

- [ ] Review performance dashboard trends
- [ ] Check certificate expiration dates
- [ ] Review and approve Dependabot PRs
- [ ] Check for security advisories
- [ ] Review cost reports

### Monthly Tasks

- [ ] Test disaster recovery procedures
- [ ] Review and update partner configurations
- [ ] Audit user access and permissions
- [ ] Clean up old logs and archived files (per retention policy)
- [ ] Review and optimize Azure resource sizing
- [ ] Update documentation with lessons learned

### Quarterly Tasks

- [ ] Conduct security audit
- [ ] Review SLA compliance reports
- [ ] Partner business reviews
- [ ] Capacity planning review
- [ ] Update runbooks with new scenarios

---

## Runbook 7: Deployment Procedures

**File:** `docs/runbooks/07-deployment-procedures.md`

Purpose: Safe deployment practices for production changes

### Pre-Deployment Checklist

- [ ] Code reviewed and approved
- [ ] All tests passing (unit, integration, E2E)
- [ ] Security scan passed
- [ ] Infrastructure changes reviewed
- [ ] Rollback plan documented
- [ ] Change window scheduled
- [ ] Stakeholders notified

### Deployment Steps

1. **Deploy to Dev** (automatic on merge)
2. **Validate in Dev** (manual testing)
3. **Deploy to Test** (requires 1 approval)
4. **UAT in Test** (partner testing if applicable)
5. **Deploy to Prod** (requires 2 approvals + 5 min wait)
6. **Post-Deployment Validation**
   - Run synthetic transactions
   - Check all dashboards
   - Monitor for 1 hour

### Rollback Procedure

If deployment fails:

```powershell
# Rollback via slot swap
az functionapp deployment slot swap \
  --name func-edi-{name}-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --slot staging \
  --action swap

# Or redeploy previous version
# Trigger GitHub Actions workflow with previous tag
```

---

## Common Requirements for ALL Runbooks

1. **Format:**
   - Markdown for easy editing
   - Clear step-by-step procedures
   - Code snippets ready to copy/paste
   - Screenshots where helpful

2. **Accessibility:**
   - Stored in GitHub repository
   - Linked from Azure Workbooks
   - Searchable
   - Version controlled

3. **Maintenance:**
   - Review after each incident
   - Update with new scenarios
   - Remove outdated information
   - Date last updated

Also provide:
1. Runbook template for creating new runbooks
2. Index/table of contents for all runbooks
3. Quick reference card (1-page cheat sheet)
4. On-call rotation schedule template
5. Escalation contact list template
```

## Expected Outcome

After running this prompt, you should have:

- ✅ 7 comprehensive operational runbooks
- ✅ Step-by-step troubleshooting procedures
- ✅ Code snippets and commands ready to use
- ✅ Incident response procedures
- ✅ Routine maintenance schedules

## Post-Creation Tasks (Human Required)

1. **Customize for your environment:**
   - Replace placeholder resource names
   - Add actual contact information
   - Update escalation paths
   - Add partner-specific details

2. **Review with team:**
   - Walk through each runbook
   - Test procedures in dev environment
   - Gather feedback and improve

3. **Make accessible:**
   - Link from Azure Workbooks
   - Bookmark in Teams
   - Print quick reference card
   - Add to onboarding checklist

## Validation Steps

1. Test each runbook procedure:
   ```powershell
   # Try each command in dev environment
   # Verify commands work as documented
   ```

2. Simulate incidents:
   - Kill a function app
   - Put message in dead-letter queue
   - Block storage access
   - Follow runbook to resolve

3. Get team feedback:
   - Schedule runbook review session
   - Document gaps or confusion
   - Update based on feedback

## Integration with Monitoring

Link runbooks from alerts:

```bicep
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'edi-incidents'
  location: 'global'
  properties: {
    groupShortName: 'EDI-Incident'
    enabled: true
    emailReceivers: [
      {
        name: 'OnCall'
        emailAddress: 'oncall@company.com'
        useCommonAlertSchema: true
      }
    ]
    webhookReceivers: [
      {
        name: 'Runbook'
        serviceUri: 'https://github.com/PointCHealth/edi-platform-core/blob/main/docs/runbooks/02-function-failure-troubleshooting.md'
      }
    ]
  }
}
```

## Next Steps

After successful completion:

- Train team on runbook usage
- Schedule regular runbook reviews
- Create runbook training videos
- Integrate with incident management system
- Track runbook usage metrics
- Update based on real incidents
