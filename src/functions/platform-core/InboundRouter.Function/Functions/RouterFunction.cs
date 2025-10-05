using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using HealthcareEDI.InboundRouter.Services;
using HealthcareEDI.InboundRouter.Models;

namespace HealthcareEDI.InboundRouter.Functions;

public class RouterFunction
{
    private readonly ILogger<RouterFunction> _logger;
    private readonly IRoutingService _routingService;

    public RouterFunction(ILogger<RouterFunction> logger, IRoutingService routingService)
    {
        _logger = logger;
        _routingService = routingService;
    }

    /// <summary>
    /// HTTP-triggered function for manual file routing
    /// </summary>
    [Function("RouteFile")]
    public async Task<HttpResponseData> RouteFile(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "route")] HttpRequestData req,
        FunctionContext executionContext)
    {
        _logger.LogInformation("Processing manual routing request");

        try
        {
            var request = await req.ReadFromJsonAsync<RouteRequest>();
            if (request == null || string.IsNullOrEmpty(request.FilePath))
            {
                var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                await badResponse.WriteStringAsync("Invalid request: FilePath is required");
                return badResponse;
            }

            var correlationId = Guid.NewGuid().ToString();
            _logger.LogInformation("Routing file {FilePath} with correlation ID {CorrelationId}", 
                request.FilePath, correlationId);

            var context = new RoutingContext
            {
                FilePath = request.FilePath,
                CorrelationId = correlationId,
                Timestamp = DateTimeOffset.UtcNow
            };

            var result = await _routingService.RouteFileAsync(context);

            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteAsJsonAsync(result);
            
            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error routing file");
            
            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteStringAsync($"Error: {ex.Message}");
            return errorResponse;
        }
    }

    /// <summary>
    /// Event Grid-triggered function for automatic routing when files arrive
    /// </summary>
    [Function("RouteFileOnBlobCreated")]
    public async Task RouteFileOnBlobCreated(
        [EventGridTrigger] EventGridEvent eventGridEvent,
        FunctionContext executionContext)
    {
        _logger.LogInformation("Processing Event Grid event: {EventType}", eventGridEvent.EventType);

        try
        {
            if (eventGridEvent.EventType == "Microsoft.Storage.BlobCreated")
            {
                var blobUrl = eventGridEvent.Subject;
                var correlationId = eventGridEvent.Id;

                _logger.LogInformation("New blob detected: {BlobUrl}, Correlation ID: {CorrelationId}",
                    blobUrl, correlationId);

                var context = new RoutingContext
                {
                    FilePath = blobUrl,
                    CorrelationId = correlationId,
                    Timestamp = eventGridEvent.EventTime
                };

                var result = await _routingService.RouteFileAsync(context);

                _logger.LogInformation("Successfully routed file to {Destination}", result.Destination);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing Event Grid event");
            throw; // Let the function runtime handle retry logic
        }
    }
}

public record RouteRequest(string FilePath);

public class EventGridEvent
{
    public string Id { get; set; } = string.Empty;
    public string EventType { get; set; } = string.Empty;
    public string Subject { get; set; } = string.Empty;
    public DateTimeOffset EventTime { get; set; }
    public object? Data { get; set; }
}
