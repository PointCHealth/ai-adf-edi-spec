namespace HealthcareEDI.Core.Models;

/// <summary>
/// Result of processing an EDI transaction
/// </summary>
public class ProcessingResult
{
    /// <summary>
    /// Indicates if processing was successful
    /// </summary>
    public bool Success { get; set; }

    /// <summary>
    /// Error message if processing failed
    /// </summary>
    public string? ErrorMessage { get; set; }

    /// <summary>
    /// Error code if processing failed
    /// </summary>
    public string? ErrorCode { get; set; }

    /// <summary>
    /// Correlation ID for tracking
    /// </summary>
    public string CorrelationId { get; set; } = string.Empty;

    /// <summary>
    /// Transaction identifier
    /// </summary>
    public string? TransactionId { get; set; }

    /// <summary>
    /// Transaction type that was processed
    /// </summary>
    public string? TransactionType { get; set; }

    /// <summary>
    /// Duration of processing in milliseconds
    /// </summary>
    public long DurationMs { get; set; }

    /// <summary>
    /// Timestamp when processing completed
    /// </summary>
    public DateTimeOffset Timestamp { get; set; } = DateTimeOffset.UtcNow;

    /// <summary>
    /// Additional result data
    /// </summary>
    public Dictionary<string, object> Data { get; set; } = new();

    /// <summary>
    /// Warnings encountered during processing
    /// </summary>
    public List<string> Warnings { get; set; } = new();

    /// <summary>
    /// Creates a successful result
    /// </summary>
    public static ProcessingResult CreateSuccess(string correlationId, string? transactionId = null)
    {
        return new ProcessingResult
        {
            Success = true,
            CorrelationId = correlationId,
            TransactionId = transactionId
        };
    }

    /// <summary>
    /// Creates a failed result
    /// </summary>
    public static ProcessingResult CreateFailure(string correlationId, string errorCode, string errorMessage)
    {
        return new ProcessingResult
        {
            Success = false,
            CorrelationId = correlationId,
            ErrorCode = errorCode,
            ErrorMessage = errorMessage
        };
    }
}
