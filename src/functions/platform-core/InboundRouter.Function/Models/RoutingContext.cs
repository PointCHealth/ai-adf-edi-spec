namespace HealthcareEDI.InboundRouter.Models;

public class RoutingContext
{
    public required string FilePath { get; set; }
    public required string CorrelationId { get; set; }
    public DateTimeOffset Timestamp { get; set; }
    public Dictionary<string, string> Metadata { get; set; } = new();
}
