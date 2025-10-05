using Azure.Messaging.ServiceBus;
using Azure.Storage.Blobs;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using HealthcareEDI.InboundRouter.Models;
using HealthcareEDI.InboundRouter.Configuration;

namespace HealthcareEDI.InboundRouter.Services;

public class RoutingService : IRoutingService
{
    private readonly ILogger<RoutingService> _logger;
    private readonly BlobServiceClient _blobServiceClient;
    private readonly ServiceBusClient _serviceBusClient;
    private readonly RoutingOptions _options;

    public RoutingService(
        ILogger<RoutingService> logger,
        BlobServiceClient blobServiceClient,
        ServiceBusClient serviceBusClient,
        IOptions<RoutingOptions> options)
    {
        _logger = logger;
        _blobServiceClient = blobServiceClient;
        _serviceBusClient = serviceBusClient;
        _options = options.Value;
    }

    public async Task<RoutingResult> RouteFileAsync(RoutingContext context)
    {
        _logger.LogInformation("Starting routing for file: {FilePath}", context.FilePath);

        try
        {
            // Parse file path to extract container and blob name
            var (containerName, blobName) = ParseFilePath(context.FilePath);

            // Download first 10KB to determine transaction type
            var blobClient = _blobServiceClient
                .GetBlobContainerClient(containerName)
                .GetBlobClient(blobName);

            var transactionType = await DetermineTransactionTypeAsync(blobClient);

            // Determine routing destination based on transaction type
            var destination = DetermineDestination(transactionType);

            // Send routing message to Service Bus
            await PublishRoutingMessageAsync(context, transactionType, destination);

            _logger.LogInformation(
                "Successfully routed file {FilePath} of type {TransactionType} to {Destination}",
                context.FilePath, transactionType, destination);

            return new RoutingResult
            {
                Success = true,
                TransactionType = transactionType,
                Destination = destination,
                CorrelationId = context.CorrelationId,
                Timestamp = DateTimeOffset.UtcNow
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error routing file {FilePath}", context.FilePath);
            throw;
        }
    }

    private (string containerName, string blobName) ParseFilePath(string filePath)
    {
        // Parse blob URL or path
        // Example: https://storage.blob.core.windows.net/inbound/file.edi
        // or: inbound/file.edi
        
        var uri = new Uri(filePath, UriKind.RelativeOrAbsolute);
        if (uri.IsAbsoluteUri)
        {
            var segments = uri.AbsolutePath.Split('/', StringSplitOptions.RemoveEmptyEntries);
            return (segments[0], string.Join("/", segments.Skip(1)));
        }
        else
        {
            var parts = filePath.Split('/', 2);
            return (parts[0], parts.Length > 1 ? parts[1] : string.Empty);
        }
    }

    private async Task<string> DetermineTransactionTypeAsync(BlobClient blobClient)
    {
        // Download first 10KB to analyze ISA/GS segments
        var downloadInfo = await blobClient.DownloadContentAsync();
        var content = downloadInfo.Value.Content.ToString();

        // Simple X12 parsing to extract transaction type from GS/ST segments
        // In production, use a proper X12 parser library
        if (content.Contains("GS*HP"))
        {
            return "270"; // Eligibility Inquiry
        }
        else if (content.Contains("GS*HS"))
        {
            return "837"; // Health Care Claim
        }
        else if (content.Contains("GS*BE"))
        {
            return "834"; // Benefit Enrollment
        }
        else if (content.Contains("GS*RA"))
        {
            return "835"; // Remittance Advice
        }

        _logger.LogWarning("Unable to determine transaction type from content");
        return "UNKNOWN";
    }

    private string DetermineDestination(string transactionType)
    {
        // Map transaction type to Service Bus queue/topic
        return transactionType switch
        {
            "270" => "eligibility-inbound",
            "271" => "eligibility-inbound",
            "837" => "claims-inbound",
            "277" => "claims-inbound",
            "834" => "enrollment-inbound",
            "835" => "remittance-inbound",
            _ => "unknown-transactions"
        };
    }

    private async Task PublishRoutingMessageAsync(
        RoutingContext context,
        string transactionType,
        string destination)
    {
        var sender = _serviceBusClient.CreateSender(_options.RoutingTopicName);

        var message = new ServiceBusMessage
        {
            Subject = transactionType,
            CorrelationId = context.CorrelationId,
            ContentType = "application/json",
            Body = BinaryData.FromString(System.Text.Json.JsonSerializer.Serialize(new
            {
                FilePath = context.FilePath,
                TransactionType = transactionType,
                Destination = destination,
                Timestamp = context.Timestamp
            }))
        };

        // Add message properties for filtering
        message.ApplicationProperties["TransactionType"] = transactionType;
        message.ApplicationProperties["Destination"] = destination;

        await sender.SendMessageAsync(message);
        
        _logger.LogInformation("Published routing message to topic {Topic}", _options.RoutingTopicName);
    }
}
