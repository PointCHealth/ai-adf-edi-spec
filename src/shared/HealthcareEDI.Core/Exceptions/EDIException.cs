namespace HealthcareEDI.Core.Exceptions;

/// <summary>
/// Base exception for all EDI processing errors
/// </summary>
public class EDIException : Exception
{
    /// <summary>
    /// Error code associated with this exception
    /// </summary>
    public string ErrorCode { get; }

    /// <summary>
    /// Correlation ID for tracking this error across distributed system
    /// </summary>
    public string? CorrelationId { get; set; }

    /// <summary>
    /// Additional context data for debugging
    /// </summary>
    public Dictionary<string, object> Context { get; } = new();

    public EDIException(string errorCode, string message) 
        : base(message)
    {
        ErrorCode = errorCode;
    }

    public EDIException(string errorCode, string message, Exception innerException) 
        : base(message, innerException)
    {
        ErrorCode = errorCode;
    }

    /// <summary>
    /// Adds context information to the exception
    /// </summary>
    public EDIException WithContext(string key, object value)
    {
        Context[key] = value;
        return this;
    }

    /// <summary>
    /// Sets the correlation ID for this exception
    /// </summary>
    public EDIException WithCorrelationId(string correlationId)
    {
        CorrelationId = correlationId;
        return this;
    }

    public override string ToString()
    {
        var details = $"ErrorCode: {ErrorCode}";
        if (!string.IsNullOrEmpty(CorrelationId))
        {
            details += $", CorrelationId: {CorrelationId}";
        }
        if (Context.Any())
        {
            var contextStr = string.Join(", ", Context.Select(kvp => $"{kvp.Key}={kvp.Value}"));
            details += $", Context: [{contextStr}]";
        }
        return $"{base.ToString()}\n{details}";
    }
}
