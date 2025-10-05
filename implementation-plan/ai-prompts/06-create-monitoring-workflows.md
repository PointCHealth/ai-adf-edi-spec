# AI Prompt: Create Monitoring & Alert Workflows

## Objective
Create automated workflows for drift detection, cost monitoring, security scanning, and operational health checks.

## Prerequisites
- Infrastructure deployed to Azure
- Application Insights configured
- Azure Cost Management enabled
- GitHub Actions workflows basics in place

## Prompt

```
I need you to create comprehensive monitoring and alerting workflows for the EDI platform to ensure operational excellence.

Context:
- Platform: Azure-based EDI transaction processing
- Monitoring: Application Insights, Azure Monitor, Cost Management
- Compliance: HIPAA, need audit trails
- Alerting: GitHub Issues, Teams notifications

Please create these workflow files:

---

## 1. Drift Detection Workflow (.github/workflows/drift-detection.yml)

Purpose: Detect when Azure resources have been manually modified and don't match Bicep templates.

Triggers:
- Scheduled: Daily at 2 AM UTC (cron: '0 2 * * *')
- Scheduled: Before each production deployment
- Manual workflow_dispatch with environment selection

Jobs:

1. **detect-infrastructure-drift**:
   - For each environment (dev, test, prod):
     - Authenticate to Azure via OIDC
     - Run 'az deployment group what-if' in validation mode
     - Compare current state vs Bicep templates
     - Parse output to identify drifted resources
   - Use matrix strategy for parallel checking

2. **analyze-drift**:
   - Depends on: detect-infrastructure-drift
   - Categorize drift by severity:
     - Critical: Security settings, network rules, encryption
     - High: Configuration changes, scaling settings
     - Medium: Tags, naming
     - Low: Cosmetic changes
   - Generate drift report

3. **report-and-alert**:
   - If critical/high drift detected:
     - Create GitHub Issue with:
       - Title: "⚠️ Infrastructure Drift Detected - [ENVIRONMENT]"
       - Labels: drift, [env], [severity]
       - Body: Detailed drift analysis with remediation steps
       - Assignee: @platform-team
     - Send Teams alert to platform channel
     - Tag on-call engineer
   - If medium/low drift:
     - Log to monitoring
     - Update existing drift tracking issue
   - If no drift:
     - Close existing drift issues
     - Log success

Requirements:
- Clear drift categorization
- Link to Azure Portal resource
- Suggest remediation (update template vs revert change)
- Track drift over time
- Exclude expected drift (tags, etc.)

---

## 2. Cost Monitoring Workflow (.github/workflows/cost-monitoring.yml)

Purpose: Monitor Azure spending and alert on budget anomalies.

Triggers:
- Scheduled: Daily at 8 AM UTC (cron: '0 8 * * *')
- Manual workflow_dispatch

Jobs:

1. **fetch-cost-data**:
   - Authenticate to Azure
   - Use Azure Cost Management API to fetch:
     - Current month spend by environment
     - Daily spend trend
     - Cost by resource type
     - Largest cost contributors
   - Compare against budget thresholds

2. **analyze-spending**:
   - Calculate:
     - Projected month-end spend
     - Variance from budget
     - Anomalous cost increases (>20% day-over-day)
     - Cost per transaction (if metrics available)
   - Identify cost optimization opportunities

3. **generate-cost-report**:
   - Create markdown cost report
   - Include:
     - Current spend vs budget table
     - Cost trend chart (ASCII or image)
     - Top 10 expensive resources
     - Recommendations for cost reduction
   - Upload as workflow artifact

4. **alert-on-anomalies**:
   - If budget exceeded or projected to exceed:
     - Create GitHub Issue: "🚨 Budget Alert: [ENVIRONMENT] - [X%] of Budget Used"
     - Send Teams alert to finance and platform teams
     - Tag budget owner
   - If anomalous increase detected:
     - Send warning notification
     - Request review
   - Daily digest to Teams (summary only)

Budget thresholds to check:
- Dev: $500/month
- Test: $1000/month  
- Prod: $5000/month
- Alert at: 80%, 90%, 100%, 110%

Requirements:
- Historical cost tracking
- Cost attribution by feature/partner
- Actionable recommendations
- Integration with Azure Budgets if configured

---

## 3. Security Audit Workflow (.github/workflows/security-audit.yml)

Purpose: Regular security scanning and compliance validation.

Triggers:
- Scheduled: Weekly on Monday at 3 AM UTC (cron: '0 3 * * 1')
- On: Pull request to main (for code changes)
- Manual workflow_dispatch

Jobs:

1. **scan-infrastructure**:
   - Scan Bicep templates with:
     - Microsoft Security DevOps (MSDO)
     - Checkov for IaC security
     - Azure Policy compliance checker
   - Check for:
     - Public endpoints
     - Weak encryption
     - Missing authentication
     - Overly permissive RBAC
     - Missing network security groups
     - Non-compliant HIPAA settings

2. **scan-application-code**:
   - Scan C# code with:
     - CodeQL (if not already running)
     - Snyk or WhiteSource for dependencies
     - SonarCloud for code quality
   - Check for:
     - Security vulnerabilities
     - Code smells
     - Hardcoded secrets (complement GitHub secret scanning)
     - SQL injection risks
     - XSS vulnerabilities

3. **scan-dependencies**:
   - Check NuGet packages for vulnerabilities
   - Check npm packages (if any frontend)
   - Check GitHub Actions for pinned versions
   - Verify all dependencies are from trusted sources

4. **compliance-check**:
   - HIPAA compliance checklist:
     - Encryption at rest: ✓/✗
     - Encryption in transit: ✓/✗
     - Access logging enabled: ✓/✗
     - Audit logs retained: ✓/✗
     - MFA enforced: ✓/✗
     - Data classification configured: ✓/✗
   - Generate compliance report

5. **report-findings**:
   - Create security report artifact
   - If critical findings:
     - Create GitHub Issue: "🔒 Security Finding: [TITLE]"
     - Label: security, [severity]
     - Assign to security team
     - Block deployments until resolved
   - Weekly summary to security team

Requirements:
- Integrate with GitHub Advanced Security
- Track finding remediation status
- Compliance reporting
- Integration with SIEM if available

---

## 4. Application Health Monitoring (.github/workflows/health-monitoring.yml)

Purpose: Proactive health checks and synthetic transactions.

Triggers:
- Scheduled: Every 15 minutes (cron: '*/15 * * * *')
- After deployments (called by CD workflow)
- Manual workflow_dispatch

Jobs:

1. **health-check-endpoints**:
   - For each function and environment:
     - Call health endpoint
     - Verify response time < 5 seconds
     - Check HTTP status 200
     - Validate response body
   - For ADF:
     - Check pipeline run status
     - Verify last successful run < 24 hours ago
   - For Service Bus:
     - Check queue depths
     - Verify no dead-letter messages
     - Check message age

2. **synthetic-transactions**:
   - Submit test EDI transaction:
     - Upload test 837 file to dev environment
     - Track through entire pipeline
     - Verify output file generated
     - Check processing time < SLA
   - Validate end-to-end flow

3. **query-application-insights**:
   - Run KQL queries:
     - Exception rate in last hour
     - Slow requests (>5s) in last hour
     - Failed dependency calls
     - HTTP 5xx errors
   - Compare against baselines

4. **alert-on-issues**:
   - If health check fails:
     - Create GitHub Issue if doesn't exist
     - Update existing issue with latest status
     - Send Teams alert
     - Tag on-call engineer
   - If synthetic transaction fails:
     - Critical alert
     - Page on-call if prod
   - If Application Insights shows anomalies:
     - Warning notification
     - Track for trending

Requirements:
- Fast execution (<5 min total)
- Minimal false positives
- Clear escalation path
- Integration with PagerDuty or similar (optional)

---

For all workflows include:

Common structure:
```yaml
name: [Workflow Name]

on:
  schedule:
    - cron: '[schedule]'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to check'
        required: false
        type: choice
        options:
          - all
          - dev
          - test
          - prod
        default: 'all'

permissions:
  contents: read
  issues: write
  id-token: write

env:
  AZURE_LOCATION: ${{ vars.AZURE_LOCATION }}

jobs:
  [job-name]:
    runs-on: ubuntu-latest
    environment: ${{ matrix.environment }}
    strategy:
      matrix:
        environment: [dev, test, prod]
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

Teams notification template:
```yaml
- name: Send Teams Notification
  if: failure()
  run: |
    curl -H "Content-Type: application/json" \
      -d '{
        "@type": "MessageCard",
        "themeColor": "FF0000",
        "title": "${{ github.workflow }} Failed",
        "text": "Environment: ${{ matrix.environment }}",
        "potentialAction": [{
          "@type": "OpenUri",
          "name": "View Run",
          "targets": [{"os": "default", "uri": "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"}]
        }]
      }' \
      ${{ secrets.TEAMS_WEBHOOK_URL }}
```

Also provide:
1. KQL queries for Application Insights
2. Cost analysis PowerShell script
3. Drift detection ignore list (for expected changes)
4. Security compliance checklist
5. Incident response playbook links
```

## Expected Outcome

After running this prompt, you should have:
- ✅ `.github/workflows/drift-detection.yml` created
- ✅ `.github/workflows/cost-monitoring.yml` created
- ✅ `.github/workflows/security-audit.yml` created
- ✅ `.github/workflows/health-monitoring.yml` created
- ✅ Comprehensive monitoring and alerting
- ✅ Automated issue creation
- ✅ Teams integration

## Validation Steps

1. Commit workflows:
   ```powershell
   git add .github/workflows/*-monitoring.yml .github/workflows/*-detection.yml .github/workflows/*-audit.yml
   git commit -m "feat: Add monitoring and alerting workflows"
   git push origin main
   ```

2. Test drift detection manually:
   ```powershell
   gh workflow run drift-detection.yml -f environment=dev
   ```

3. Verify drift detection:
   - Make a manual change in Azure Portal (e.g., add a tag)
   - Wait for scheduled run or trigger manually
   - Check if issue is created

4. Test cost monitoring:
   ```powershell
   gh workflow run cost-monitoring.yml
   ```

5. Review outputs:
   - Check workflow artifacts for reports
   - Verify Teams notifications if configured
   - Review created issues

## Troubleshooting

**Drift Detection False Positives**
- Add expected changes to ignore list
- Update Bicep templates to match reality
- Check parameter file values

**Cost API Access Denied**
- Verify service principal has Cost Management Reader role
- Check subscription-level permissions
- Use Azure Portal to verify API access

**Teams Webhook Not Working**
- Verify webhook URL is correct
- Check webhook is enabled in Teams
- Test with curl manually first

**Health Checks Timing Out**
- Increase timeout values
- Check network connectivity from GitHub Actions
- Verify Function Apps are running

## Next Steps

After successful completion:
- Configure alert recipients in Teams
- Set up PagerDuty integration (optional)
- Proceed to [07-create-dependabot-config.md](07-create-dependabot-config.md)
- Create monitoring dashboards [16-create-monitoring-dashboards.md](16-create-monitoring-dashboards.md)
