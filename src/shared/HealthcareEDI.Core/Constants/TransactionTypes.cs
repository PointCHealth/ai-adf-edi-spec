namespace HealthcareEDI.Core.Constants;

/// <summary>
/// X12 transaction type codes for healthcare EDI
/// </summary>
public static class TransactionTypes
{
    /// <summary>
    /// 270 - Healthcare Eligibility/Benefit Inquiry
    /// </summary>
    public const string Eligibility270 = "270";

    /// <summary>
    /// 271 - Healthcare Eligibility/Benefit Response
    /// </summary>
    public const string Eligibility271 = "271";

    /// <summary>
    /// 834 - Benefit Enrollment and Maintenance
    /// </summary>
    public const string Enrollment834 = "834";

    /// <summary>
    /// 835 - Healthcare Claim Payment/Advice
    /// </summary>
    public const string Remittance835 = "835";

    /// <summary>
    /// 837 - Healthcare Claim (Professional/Institutional/Dental)
    /// </summary>
    public const string Claims837 = "837";

    /// <summary>
    /// 277 - Healthcare Claim Status Request/Response
    /// </summary>
    public const string ClaimStatus277 = "277";

    /// <summary>
    /// 999 - Implementation Acknowledgment
    /// </summary>
    public const string Acknowledgment999 = "999";

    /// <summary>
    /// 997 - Functional Acknowledgment
    /// </summary>
    public const string Acknowledgment997 = "997";

    /// <summary>
    /// Unknown or unsupported transaction type
    /// </summary>
    public const string Unknown = "UNKNOWN";

    /// <summary>
    /// Determines if the transaction type is valid
    /// </summary>
    public static bool IsValid(string transactionType)
    {
        return transactionType switch
        {
            Eligibility270 or Eligibility271 or Enrollment834 or
            Remittance835 or Claims837 or ClaimStatus277 or
            Acknowledgment999 or Acknowledgment997 => true,
            _ => false
        };
    }

    /// <summary>
    /// Gets a human-readable description of the transaction type
    /// </summary>
    public static string GetDescription(string transactionType)
    {
        return transactionType switch
        {
            Eligibility270 => "Eligibility Inquiry",
            Eligibility271 => "Eligibility Response",
            Enrollment834 => "Benefit Enrollment",
            Remittance835 => "Claim Payment/Remittance",
            Claims837 => "Healthcare Claim",
            ClaimStatus277 => "Claim Status",
            Acknowledgment999 => "Implementation Acknowledgment",
            Acknowledgment997 => "Functional Acknowledgment",
            _ => "Unknown Transaction Type"
        };
    }
}
