namespace HealthcareEDI.Core.Extensions;

/// <summary>
/// Extension methods for DateTime and DateTimeOffset operations
/// </summary>
public static class DateTimeExtensions
{
    /// <summary>
    /// Converts a DateTimeOffset to X12 date format (CCYYMMDD)
    /// </summary>
    public static string ToX12Date(this DateTimeOffset date)
    {
        return date.ToString("yyyyMMdd");
    }

    /// <summary>
    /// Converts a DateTimeOffset to X12 time format (HHMM or HHMMSS)
    /// </summary>
    public static string ToX12Time(this DateTimeOffset date, bool includeSeconds = false)
    {
        return includeSeconds ? date.ToString("HHmmss") : date.ToString("HHmm");
    }

    /// <summary>
    /// Converts a DateTimeOffset to X12 timestamp format (CCYYMMDDHHMM)
    /// </summary>
    public static string ToX12Timestamp(this DateTimeOffset date)
    {
        return date.ToString("yyyyMMddHHmm");
    }

    /// <summary>
    /// Parses an X12 date format (CCYYMMDD) to DateTimeOffset
    /// </summary>
    public static DateTimeOffset FromX12Date(string x12Date)
    {
        if (x12Date.Length != 8)
            throw new ArgumentException("X12 date must be 8 characters (CCYYMMDD)", nameof(x12Date));

        var year = int.Parse(x12Date[..4]);
        var month = int.Parse(x12Date.Substring(4, 2));
        var day = int.Parse(x12Date.Substring(6, 2));

        return new DateTimeOffset(year, month, day, 0, 0, 0, TimeSpan.Zero);
    }

    /// <summary>
    /// Parses an X12 time format (HHMM or HHMMSS) to TimeSpan
    /// </summary>
    public static TimeSpan FromX12Time(string x12Time)
    {
        if (x12Time.Length != 4 && x12Time.Length != 6)
            throw new ArgumentException("X12 time must be 4 or 6 characters (HHMM or HHMMSS)", nameof(x12Time));

        var hour = int.Parse(x12Time[..2]);
        var minute = int.Parse(x12Time.Substring(2, 2));
        var second = x12Time.Length == 6 ? int.Parse(x12Time.Substring(4, 2)) : 0;

        return new TimeSpan(hour, minute, second);
    }

    /// <summary>
    /// Gets the start of the day in UTC
    /// </summary>
    public static DateTimeOffset StartOfDay(this DateTimeOffset date)
    {
        return new DateTimeOffset(date.Year, date.Month, date.Day, 0, 0, 0, date.Offset);
    }

    /// <summary>
    /// Gets the end of the day in UTC
    /// </summary>
    public static DateTimeOffset EndOfDay(this DateTimeOffset date)
    {
        return new DateTimeOffset(date.Year, date.Month, date.Day, 23, 59, 59, 999, date.Offset);
    }
}
