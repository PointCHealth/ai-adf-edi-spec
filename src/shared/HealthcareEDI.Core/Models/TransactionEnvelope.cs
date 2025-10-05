namespace HealthcareEDI.Core.Models;

/// <summary>
/// Represents a complete X12 transaction envelope with metadata
/// </summary>
public class TransactionEnvelope
{
    /// <summary>
    /// Unique identifier for this transaction
    /// </summary>
    public string TransactionId { get; set; } = string.Empty;

    /// <summary>
    /// X12 transaction type (270, 834, 837, etc.)
    /// </summary>
    public string TransactionType { get; set; } = string.Empty;

    /// <summary>
    /// Sender identifier from ISA segment
    /// </summary>
    public string SenderId { get; set; } = string.Empty;

    /// <summary>
    /// Receiver identifier from ISA segment
    /// </summary>
    public string ReceiverId { get; set; } = string.Empty;

    /// <summary>
    /// Interchange control number
    /// </summary>
    public string InterchangeControlNumber { get; set; } = string.Empty;

    /// <summary>
    /// Group control number
    /// </summary>
    public string GroupControlNumber { get; set; } = string.Empty;

    /// <summary>
    /// Transaction set control number
    /// </summary>
    public string TransactionControlNumber { get; set; } = string.Empty;

    /// <summary>
    /// Raw X12 content
    /// </summary>
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// Timestamp when transaction was received
    /// </summary>
    public DateTimeOffset Timestamp { get; set; } = DateTimeOffset.UtcNow;

    /// <summary>
    /// Correlation ID for tracking across system
    /// </summary>
    public string CorrelationId { get; set; } = string.Empty;

    /// <summary>
    /// Trading partner identifier
    /// </summary>
    public string? PartnerId { get; set; }

    /// <summary>
    /// Additional metadata
    /// </summary>
    public Dictionary<string, string> Metadata { get; set; } = new();
}
