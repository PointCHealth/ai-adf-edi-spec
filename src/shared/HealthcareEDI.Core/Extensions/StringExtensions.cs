namespace HealthcareEDI.Core.Extensions;

/// <summary>
/// Extension methods for string manipulation commonly used in EDI processing
/// </summary>
public static class StringExtensions
{
    /// <summary>
    /// Removes all whitespace from a string
    /// </summary>
    public static string RemoveWhitespace(this string input)
    {
        return new string(input.Where(c => !char.IsWhiteSpace(c)).ToArray());
    }

    /// <summary>
    /// Truncates a string to a maximum length
    /// </summary>
    public static string Truncate(this string input, int maxLength)
    {
        if (string.IsNullOrEmpty(input) || input.Length <= maxLength)
            return input;

        return input[..maxLength];
    }

    /// <summary>
    /// Checks if a string is null, empty, or whitespace
    /// </summary>
    public static bool IsNullOrWhiteSpace(this string? input)
    {
        return string.IsNullOrWhiteSpace(input);
    }

    /// <summary>
    /// Pads a string to the right with a specified character
    /// </summary>
    public static string PadRightWithChar(this string input, int totalWidth, char paddingChar = ' ')
    {
        if (input.Length >= totalWidth)
            return input;

        return input.PadRight(totalWidth, paddingChar);
    }

    /// <summary>
    /// Masks sensitive data for logging (shows first and last 4 characters)
    /// </summary>
    public static string MaskForLogging(this string input, int visibleChars = 4)
    {
        if (string.IsNullOrEmpty(input) || input.Length <= visibleChars * 2)
            return input;

        var first = input[..visibleChars];
        var last = input[^visibleChars..];
        var masked = new string('*', input.Length - (visibleChars * 2));

        return $"{first}{masked}{last}";
    }

    /// <summary>
    /// Converts a string to a safe filename
    /// </summary>
    public static string ToSafeFileName(this string input)
    {
        var invalidChars = Path.GetInvalidFileNameChars();
        return new string(input.Select(c => invalidChars.Contains(c) ? '_' : c).ToArray());
    }
}
