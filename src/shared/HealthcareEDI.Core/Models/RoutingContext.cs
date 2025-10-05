namespace HealthcareEDI.Core.Models;

/// <summary>
/// Context information for routing a transaction through the platform
/// </summary>
public class RoutingContext
{
    /// <summary>
    /// File path or blob URI of the EDI file
    /// </summary>
    public string FilePath { get; set; } = string.Empty;

    /// <summary>
    /// Correlation ID for tracking
    /// </summary>
    public string CorrelationId { get; set; } = Guid.NewGuid().ToString();

    /// <summary>
    /// Timestamp when routing started
    /// </summary>
    public DateTimeOffset Timestamp { get; set; } = DateTimeOffset.UtcNow;

    /// <summary>
    /// Transaction type detected from file
    /// </summary>
    public string? TransactionType { get; set; }

    /// <summary>
    /// Trading partner identifier
    /// </summary>
    public string? PartnerId { get; set; }

    /// <summary>
    /// Source system or partner  that submitted the file
    /// </summary>
    public string? Source { get; set; }

    /// <summary>
    /// Additional metadata from the file or submission
    /// </summary>
    public Dictionary<string, string> Metadata { get; set; } = new();
}
