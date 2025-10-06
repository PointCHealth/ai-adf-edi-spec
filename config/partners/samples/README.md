# Sample Partner Configurations

This directory contains sample partner configuration files for testing the EDI.Configuration system.

## Files

| File | Partner Type | Status | Transactions | Endpoint |
|------|-------------|---------|--------------|----------|
| `PARTNERA.json` | EXTERNAL | active | 270, 271, 837, 835 | SFTP |
| `PARTNERB.json` | EXTERNAL | active | 270, 271 | Service Bus |
| `INTERNAL-CLAIMS.json` | INTERNAL | active | 837, 277 | Database |
| `TEST001.json` | EXTERNAL | inactive | 270, 271 | SFTP (localhost) |

## Upload to Azure Blob Storage

### Using Azure CLI

```powershell
# Set variables
$storageAccount = "stedideveasus2"
$container = "partner-configs"

# Upload all sample configs
az storage blob upload `
  --account-name $storageAccount `
  --container-name $container `
  --name "partners/PARTNERA.json" `
  --file ".\PARTNERA.json" `
  --auth-mode login

az storage blob upload `
  --account-name $storageAccount `
  --container-name $container `
  --name "partners/PARTNERB.json" `
  --file ".\PARTNERB.json" `
  --auth-mode login

az storage blob upload `
  --account-name $storageAccount `
  --container-name $container `
  --name "partners/INTERNAL-CLAIMS.json" `
  --file ".\INTERNAL-CLAIMS.json" `
  --auth-mode login

az storage blob upload `
  --account-name $storageAccount `
  --container-name $container `
  --name "partners/TEST001.json" `
  --file ".\TEST001.json" `
  --auth-mode login
```

### Using PowerShell (Bulk Upload)

```powershell
# Set variables
$storageAccount = "stedideveasus2"
$container = "partner-configs"
$localPath = "."

# Get all JSON files
Get-ChildItem -Path $localPath -Filter "*.json" | ForEach-Object {
    $blobName = "partners/$($_.Name)"
    Write-Host "Uploading $blobName..."
    
    az storage blob upload `
      --account-name $storageAccount `
      --container-name $container `
      --name $blobName `
      --file $_.FullName `
      --auth-mode login `
      --overwrite
}

Write-Host "Upload complete!"
```

### Using Azure Storage Explorer

1. Open Azure Storage Explorer
2. Navigate to: `stedideveasus2` → `Blob Containers` → `partner-configs`
3. Create folder: `partners/` (if not exists)
4. Upload all `.json` files to the `partners/` folder

## Validation

### Validate JSON Syntax

```powershell
# PowerShell
Get-ChildItem -Filter "*.json" | ForEach-Object {
    Write-Host "Validating $($_.Name)..."
    try {
        Get-Content $_.FullName | ConvertFrom-Json | Out-Null
        Write-Host "  ✅ Valid" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Invalid: $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

### Validate Against Schema

```powershell
# Requires: npm install -g ajv-cli

ajv validate `
  -s ../partners.schema.json `
  -d "*.json"
```

## Testing

### Test 1: Load All Partners

```csharp
var partners = await partnerConfig.GetAllPartnersAsync();
Console.WriteLine($"Loaded {partners.Count()} partners");
// Expected: 4 partners
```

### Test 2: Get Active Partners Only

```csharp
var activePartners = await partnerConfig.GetActivePartnersAsync();
Console.WriteLine($"Active: {activePartners.Count()}");
// Expected: 3 partners (TEST001 is inactive)
```

### Test 3: Filter by Transaction Type

```csharp
var eligibilityPartners = await partnerConfig
    .GetPartnersByTransactionAsync("270");
Console.WriteLine($"Supports 270: {eligibilityPartners.Count()}");
// Expected: 3 partners (PARTNERA, PARTNERB, TEST001)
```

### Test 4: Validate Transaction Support

```csharp
var partner = await partnerConfig.GetPartnerAsync("PARTNERA");
Console.WriteLine($"PARTNERA supports 270: {partner.SupportsTransaction("270")}");
Console.WriteLine($"PARTNERA supports 834: {partner.SupportsTransaction("834")}");
// Expected: True, False
```

## Customization

To create your own partner configuration:

1. Copy one of the sample files
2. Update the `partnerCode`, `name`, and other properties
3. Validate the JSON structure
4. Upload to blob storage
5. Wait for auto-refresh (60 seconds) or manually refresh cache

## Schema Reference

See [partners.schema.json](../partners.schema.json) for the complete JSON schema.

## Related Documents

- [Partner Configuration Integration Guide](../../implementation-plan/24-partner-config-integration-guide.md)
- [Partner Configuration Schema](../../implementation-plan/19-partner-configuration-schema.md)
- [Partner Onboarding Playbook](../../implementation-plan/12-partner-onboarding-playbook.md)
