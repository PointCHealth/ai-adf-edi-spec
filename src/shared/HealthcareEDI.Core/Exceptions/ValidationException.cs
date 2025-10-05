using HealthcareEDI.Core.Constants;

namespace HealthcareEDI.Core.Exceptions;

/// <summary>
/// Exception thrown when validation of EDI content fails
/// </summary>
public class ValidationException : EDIException
{
    /// <summary>
    /// The field or element that failed validation
    /// </summary>
    public string? Field { get; set; }

    /// <summary>
    /// The validation rule that failed
    /// </summary>
    public string? Rule { get; set; }

    /// <summary>
    /// The value that failed validation
    /// </summary>
    public object? Value { get; set; }

    public ValidationException(string message) 
        : base(ErrorCodes.ValidationError, message)
    {
    }

    public ValidationException(string message, Exception innerException) 
        : base(ErrorCodes.ValidationError, message, innerException)
    {
    }

    public ValidationException(string errorCode, string message) 
        : base(errorCode, message)
    {
    }

    /// <summary>
    /// Sets the field that failed validation
    /// </summary>
    public ValidationException ForField(string field)
    {
        Field = field;
        WithContext("Field", field);
        return this;
    }

    /// <summary>
    /// Sets the validation rule that failed
    /// </summary>
    public ValidationException WithRule(string rule)
    {
        Rule = rule;
        WithContext("Rule", rule);
        return this;
    }

    /// <summary>
    /// Sets the value that failed validation
    /// </summary>
    public ValidationException WithValue(object value)
    {
        Value = value;
        WithContext("Value", value);
        return this;
    }
}
