namespace HealthcareEDI.InboundRouter.Models;

public class RoutingResult
{
    public bool Success { get; set; }
    public required string TransactionType { get; set; }
    public required string Destination { get; set; }
    public required string CorrelationId { get; set; }
    public DateTimeOffset Timestamp { get; set; }
    public string? ErrorMessage { get; set; }
}
