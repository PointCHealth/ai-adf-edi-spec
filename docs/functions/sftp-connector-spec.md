# Function Specification: SftpConnector

**Repository:** edi-connectors  
**Project Path:** `/functions/SftpConnector.Function`  
**Azure Function Name:** `func-edi-sftp-{env}-eastus2`  
**Runtime:** .NET 9 Isolated  
**Last Updated:** 2025-10-05

---

## Overview

The SftpConnector function handles bidirectional SFTP file transfer with trading partners. It downloads inbound files from partner SFTP servers and uploads outbound files to partner-designated folders.

---

## Responsibilities

1. **Inbound Download:** Poll partner SFTP servers for new files (timer-based)
2. **Outbound Upload:** Upload files to partner SFTP servers (queue-triggered)
3. **Authentication:** Manage SSH keys and passwords from Key Vault
4. **Error Handling:** Retry transient failures, alert on persistent issues
5. **Idempotency:** Prevent duplicate downloads/uploads
6. **Audit Trail:** Log all file transfers with timestamps and checksums

---

## Triggers

### 1. Timer Trigger (Inbound Download)

**Trigger Type:** `TimerTrigger`  
**Schedule:** `0 */15 * * * *` (every 15 minutes)

```csharp
[Function("SftpDownload")]
public async Task RunDownload(
    [TimerTrigger("0 */15 * * * *")] TimerInfo timerInfo,
    FunctionContext context)
{
    var logger = context.GetLogger<SftpConnector>();
    
    // Get all partners with SFTP inbound config
    var partners = await _configService.GetPartnersWithSftpInboundAsync();
    
    foreach (var partner in partners)
    {
        try
        {
            await DownloadFilesForPartnerAsync(partner);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to download from partner {PartnerId}", partner.Id);
        }
    }
}
```

### 2. Service Bus Queue (Outbound Upload)

**Trigger Type:** `ServiceBusTrigger`  
**Queue Name:** `sftp-upload-queue`

**Message Schema:**

```json
{
  "partnerId": "partner001",
  "blobUrl": "https://storage.../processed/outbound/partner001/834_20251005.x12",
  "targetFileName": "834_POINTC_20251005_001.x12",
  "targetFolder": "/outbound/",
  "priority": "normal",
  "retryCount": 0
}
```

```csharp
[Function("SftpUpload")]
public async Task RunUpload(
    [ServiceBusTrigger("sftp-upload-queue")] ServiceBusReceivedMessage message,
    ServiceBusMessageActions messageActions,
    FunctionContext context)
{
    var uploadRequest = JsonSerializer.Deserialize<SftpUploadRequest>(message.Body);
    
    try
    {
        await UploadFileAsync(uploadRequest);
        await messageActions.CompleteMessageAsync(message);
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Failed to upload to partner {PartnerId}", uploadRequest.PartnerId);
        
        // Retry logic
        if (uploadRequest.RetryCount < 3)
        {
            uploadRequest.RetryCount++;
            await messageActions.AbandonMessageAsync(message);
        }
        else
        {
            await messageActions.DeadLetterMessageAsync(message, ex.Message);
        }
    }
}
```

---

## Processing Logic

### Inbound Download Flow

```csharp
private async Task DownloadFilesForPartnerAsync(PartnerConfig partner)
{
    // 1. Get SFTP credentials from Key Vault
    var credentials = await _keyVaultService.GetSftpCredentialsAsync(partner.Id);
    
    // 2. Connect to SFTP server
    using var sftpClient = CreateSftpClient(partner.SftpConfig, credentials);
    sftpClient.Connect();
    
    // 3. List files in inbound folder
    var remoteFiles = sftpClient.ListDirectory(partner.SftpConfig.InboundFolder)
        .Where(f => !f.IsDirectory && !f.Name.StartsWith("."))
        .ToList();
    
    // 4. Filter already-downloaded files
    var newFiles = await FilterNewFilesAsync(partner.Id, remoteFiles);
    
    foreach (var remoteFile in newFiles)
    {
        try
        {
            // 5. Download file content
            using var fileStream = new MemoryStream();
            sftpClient.DownloadFile(remoteFile.FullName, fileStream);
            fileStream.Position = 0;
            
            // 6. Upload to Azure Blob Storage
            var blobName = $"raw/inbound/{partner.Id}/{remoteFile.Name}";
            var blobClient = _storageClient.GetBlobClient(blobName);
            await blobClient.UploadAsync(fileStream, overwrite: false);
            
            // 7. Record download in tracking table
            await _trackingService.RecordDownloadAsync(
                partner.Id,
                remoteFile.Name,
                remoteFile.Length,
                remoteFile.LastWriteTimeUtc);
            
            // 8. Archive or delete remote file (per partner config)
            if (partner.SftpConfig.ArchiveAfterDownload)
            {
                var archivePath = $"{partner.SftpConfig.ArchiveFolder}/{remoteFile.Name}";
                sftpClient.RenameFile(remoteFile.FullName, archivePath);
            }
            else if (partner.SftpConfig.DeleteAfterDownload)
            {
                sftpClient.DeleteFile(remoteFile.FullName);
            }
            
            _logger.LogInformation(
                "Downloaded {FileName} from {PartnerId} ({FileSize} bytes)",
                remoteFile.Name,
                partner.Id,
                remoteFile.Length);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, 
                "Failed to download {FileName} from {PartnerId}",
                remoteFile.Name,
                partner.Id);
        }
    }
    
    sftpClient.Disconnect();
}
```

### Outbound Upload Flow

```csharp
private async Task UploadFileAsync(SftpUploadRequest request)
{
    // 1. Get partner config and credentials
    var partner = await _configService.GetPartnerConfigAsync(request.PartnerId);
    var credentials = await _keyVaultService.GetSftpCredentialsAsync(request.PartnerId);
    
    // 2. Download file from blob storage
    var blobClient = new BlobClient(new Uri(request.BlobUrl), _credential);
    using var fileStream = new MemoryStream();
    await blobClient.DownloadToAsync(fileStream);
    fileStream.Position = 0;
    
    // 3. Connect to partner SFTP server
    using var sftpClient = CreateSftpClient(partner.SftpConfig, credentials);
    sftpClient.Connect();
    
    // 4. Upload file
    var remotePath = $"{request.TargetFolder}{request.TargetFileName}";
    sftpClient.UploadFile(fileStream, remotePath, canOverride: false);
    
    // 5. Verify upload (optional - check file exists and size matches)
    var uploadedFile = sftpClient.Get(remotePath);
    if (uploadedFile.Length != fileStream.Length)
    {
        throw new Exception($"Upload verification failed: size mismatch");
    }
    
    // 6. Record upload in tracking table
    await _trackingService.RecordUploadAsync(
        request.PartnerId,
        request.TargetFileName,
        fileStream.Length,
        remotePath);
    
    // 7. Move blob to archive (optional)
    var archiveBlobName = request.BlobUrl.Replace("/processed/", "/archive/");
    var archiveBlobClient = new BlobClient(new Uri(archiveBlobName), _credential);
    await archiveBlobClient.StartCopyFromUriAsync(blobClient.Uri);
    
    _logger.LogInformation(
        "Uploaded {FileName} to {PartnerId} ({FileSize} bytes)",
        request.TargetFileName,
        request.PartnerId,
        fileStream.Length);
    
    sftpClient.Disconnect();
}
```

### SFTP Client Creation

```csharp
private SftpClient CreateSftpClient(SftpConfig config, SftpCredentials credentials)
{
    AuthenticationMethod authMethod;
    
    if (credentials.AuthType == "PrivateKey")
    {
        // SSH key authentication
        var keyFile = new PrivateKeyFile(
            new MemoryStream(Encoding.UTF8.GetBytes(credentials.PrivateKey)),
            credentials.Passphrase);
        authMethod = new PrivateKeyAuthenticationMethod(credentials.Username, keyFile);
    }
    else
    {
        // Password authentication
        authMethod = new PasswordAuthenticationMethod(credentials.Username, credentials.Password);
    }
    
    var connectionInfo = new ConnectionInfo(
        config.Host,
        config.Port,
        credentials.Username,
        authMethod)
    {
        Timeout = TimeSpan.FromSeconds(30)
    };
    
    return new SftpClient(connectionInfo);
}
```

---

## Idempotency

### Download Tracking Table (SQL)

```sql
CREATE TABLE SftpDownloadHistory (
    Id INT IDENTITY PRIMARY KEY,
    PartnerId VARCHAR(50) NOT NULL,
    FileName VARCHAR(255) NOT NULL,
    FileSize BIGINT NOT NULL,
    RemoteLastModified DATETIME2 NOT NULL,
    DownloadedAt DATETIME2 DEFAULT GETUTCDATE(),
    BlobUrl NVARCHAR(500),
    UNIQUE (PartnerId, FileName, RemoteLastModified)
);
```

### Upload Tracking Table (SQL)

```sql
CREATE TABLE SftpUploadHistory (
    Id INT IDENTITY PRIMARY KEY,
    PartnerId VARCHAR(50) NOT NULL,
    FileName VARCHAR(255) NOT NULL,
    FileSize BIGINT NOT NULL,
    RemotePath NVARCHAR(500),
    UploadedAt DATETIME2 DEFAULT GETUTCDATE(),
    BlobUrl NVARCHAR(500),
    UNIQUE (PartnerId, FileName, UploadedAt)
);
```

---

## Configuration

### Partner SFTP Config (JSON)

Stored in `config/partners/{partnerId}/sftp-config.json`:

```json
{
  "inbound": {
    "enabled": true,
    "host": "sftp.partner001.com",
    "port": 22,
    "inboundFolder": "/from_pointc/",
    "archiveFolder": "/from_pointc/archive/",
    "archiveAfterDownload": true,
    "deleteAfterDownload": false,
    "filePattern": "*.x12"
  },
  "outbound": {
    "enabled": true,
    "host": "sftp.partner001.com",
    "port": 22,
    "outboundFolder": "/to_pointc/",
    "fileNamingPattern": "{transactionType}_POINTC_{date}_{sequence}.x12"
  },
  "credentials": {
    "authType": "PrivateKey",
    "keyVaultSecretName": "sftp-partner001-privatekey",
    "username": "pointc_user"
  }
}
```

### Application Settings

```json
{
  "ServiceBus__ConnectionString": "@Microsoft.KeyVault(...)",
  "ServiceBus__SftpUploadQueueName": "sftp-upload-queue",
  "SqlDatabase__ConnectionString": "@Microsoft.KeyVault(...)",
  "Storage__ConnectionString": "@Microsoft.KeyVault(...)",
  "KeyVault__VaultUri": "https://kv-edi-prod-eastus2.vault.azure.net/",
  "SftpConnector__DownloadSchedule": "0 */15 * * * *",
  "SftpConnector__ConnectionTimeout": "00:00:30",
  "SftpConnector__MaxRetries": 3
}
```

---

## Error Handling

### Retry Strategy

| Error Type | Action | Retry |
|-----------|--------|-------|
| **Connection Timeout** | Retry with exponential backoff | 3 attempts |
| **Authentication Failed** | Alert operations team | No retry |
| **File Not Found (upload)** | Dead letter message | No retry |
| **Permission Denied** | Alert operations team | No retry |
| **Disk Full (remote)** | Retry after 1 hour | 3 attempts |
| **Network Unreachable** | Retry after 5 minutes | 5 attempts |

### Alerting

| Alert | Condition | Severity |
|-------|-----------|----------|
| SFTP Authentication Failure | Any partner auth fails | High |
| No Files Downloaded | 24 hours with no downloads (if expected) | Medium |
| Upload Queue Backlog | > 100 messages in queue for 1 hour | High |
| Connection Timeouts | > 10% of connections timeout in 1 hour | Medium |

---

## Security

### Key Vault Secrets

**Private Key Storage:**
- Secret Name: `sftp-{partnerId}-privatekey`
- Format: PEM-encoded RSA private key (OpenSSH format)
- Rotation: Annual

**Password Storage:**
- Secret Name: `sftp-{partnerId}-password`
- Rotation: Quarterly

### Network Security

**Outbound IP Whitelisting:**
- Function App uses NAT Gateway for static outbound IP
- Partners whitelist NAT Gateway IP: `52.x.x.x`

**Connection Security:**
- SSH protocol (port 22)
- Host key verification enabled
- TLS 1.2+ for control channel

---

## Monitoring

### Application Insights Metrics

```csharp
// Custom metrics
_telemetryClient.TrackMetric("SftpConnector.FilesDownloaded", 1, 
    new Dictionary<string, string> { 
        { "partnerId", partnerId },
        { "fileSize", fileSize.ToString() }
    });

_telemetryClient.TrackMetric("SftpConnector.FilesUploaded", 1,
    new Dictionary<string, string> {
        { "partnerId", partnerId }
    });

_telemetryClient.TrackMetric("SftpConnector.ConnectionDuration", duration.TotalMilliseconds,
    new Dictionary<string, string> {
        { "partnerId", partnerId },
        { "operation", "download" }
    });
```

### KQL Queries

**Files downloaded by partner:**

```kql
customMetrics
| where name == "SftpConnector.FilesDownloaded"
| extend partnerId = tostring(customDimensions.partnerId)
| summarize count() by partnerId, bin(timestamp, 1h)
| render timechart
```

**Failed connections:**

```kql
traces
| where message contains "Failed to" and message contains "SFTP"
| extend partnerId = tostring(customDimensions.partnerId)
| summarize count() by partnerId, bin(timestamp, 15m)
| where count_ > 3
```

---

## Testing

### Unit Tests

```csharp
[Fact]
public async Task DownloadFile_Success_UploadsToBlob()
{
    // Arrange: Mock SFTP server
    var mockSftpClient = new Mock<ISftpClient>();
    mockSftpClient.Setup(x => x.ListDirectory(It.IsAny<string>()))
        .Returns(new[] { 
            CreateMockFile("test.x12", 1024) 
        });
    
    // Act
    await _connector.DownloadFilesForPartnerAsync("partner001");
    
    // Assert
    var blob = _blobContainer.GetBlobClient("raw/inbound/partner001/test.x12");
    Assert.True(await blob.ExistsAsync());
}
```

### Integration Tests

Use Docker container running OpenSSH server for integration tests:

```yaml
# docker-compose.test.yml
services:
  sftp-test:
    image: atmoz/sftp
    ports:
      - "2222:22"
    command: testuser:testpass:::upload,download
```

---

## Dependencies

```xml
<ItemGroup>
  <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.21.0" />
  <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Timer" Version="4.3.0" />
  <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.ServiceBus" Version="5.16.0" />
  <PackageReference Include="SSH.NET" Version="2023.0.0" />
  <PackageReference Include="Azure.Storage.Blobs" Version="12.19.0" />
  <PackageReference Include="Azure.Security.KeyVault.Secrets" Version="4.5.0" />
  <PackageReference Include="Microsoft.Data.SqlClient" Version="5.1.0" />
</ItemGroup>
```

---

**Last Updated:** 2025-10-05  
**Owner:** Platform Engineering Team
