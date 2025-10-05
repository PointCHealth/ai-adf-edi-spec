using HealthcareEDI.Core.Constants;

namespace HealthcareEDI.Core.Exceptions;

/// <summary>
/// Exception thrown when parsing X12 EDI content fails
/// </summary>
public class ParsingException : EDIException
{
    /// <summary>
    /// The segment or line where the parsing error occurred
    /// </summary>
    public string? Segment { get; set; }

    /// <summary>
    /// The position in the file where the error occurred
    /// </summary>
    public int? Position { get; set; }

    public ParsingException(string message) 
        : base(ErrorCodes.ParsingError, message)
    {
    }

    public ParsingException(string message, Exception innerException) 
        : base(ErrorCodes.ParsingError, message, innerException)
    {
    }

    public ParsingException(string errorCode, string message) 
        : base(errorCode, message)
    {
    }

    /// <summary>
    /// Sets the segment where the error occurred
    /// </summary>
    public ParsingException AtSegment(string segment)
    {
        Segment = segment;
        WithContext("Segment", segment);
        return this;
    }

    /// <summary>
    /// Sets the position where the error occurred
    /// </summary>
    public ParsingException AtPosition(int position)
    {
        Position = position;
        WithContext("Position", position);
        return this;
    }
}
