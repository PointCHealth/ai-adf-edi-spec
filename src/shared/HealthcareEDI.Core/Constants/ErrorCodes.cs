namespace HealthcareEDI.Core.Constants;

/// <summary>
/// Error codes used throughout the EDI platform
/// </summary>
public static class ErrorCodes
{
    // Parsing Errors (1xxx)
    public const string ParsingError = "1000";
    public const string InvalidSegment = "1001";
    public const string MissingRequiredSegment = "1002";
    public const string InvalidElementFormat = "1003";
    public const string InvalidEnvelope = "1004";

    // Validation Errors (2xxx)
    public const string ValidationError = "2000";
    public const string InvalidTransactionType = "2001";
    public const string MissingRequiredElement = "2002";
    public const string InvalidElementValue = "2003";
    public const string InvalidControlNumber = "2004";

    // Routing Errors (3xxx)
    public const string RoutingError = "3000";
    public const string PartnerNotFound = "3001";
    public const string NoRoutingRuleFound = "3002";
    public const string InvalidDestination = "3003";

    // Storage Errors (4xxx)
    public const string StorageError = "4000";
    public const string BlobNotFound = "4001";
    public const string BlobAccessDenied = "4002";
    public const string StorageQuotaExceeded = "4003";

    // Messaging Errors (5xxx)
    public const string MessagingError = "5000";
    public const string ServiceBusConnectionError = "5001";
    public const string MessagePublishError = "5002";
    public const string DeadLetterError = "5003";

    // Mapping Errors (6xxx)
    public const string MappingError = "6000";
    public const string MappingRuleNotFound = "6001";
    public const string TransformationError = "6002";
    public const string TargetFormatError = "6003";

    // Configuration Errors (7xxx)
    public const string ConfigurationError = "7000";
    public const string PartnerConfigNotFound = "7001";
    public const string InvalidConfiguration = "7002";
    public const string ConfigurationLoadError = "7003";

    // General Errors (9xxx)
    public const string GeneralError = "9000";
    public const string UnexpectedError = "9001";
    public const string TimeoutError = "9002";
    public const string AuthenticationError = "9003";
    public const string AuthorizationError = "9004";

    /// <summary>
    /// Gets a human-readable description of the error code
    /// </summary>
    public static string GetDescription(string errorCode)
    {
        return errorCode switch
        {
            ParsingError => "EDI parsing error",
            InvalidSegment => "Invalid segment format",
            MissingRequiredSegment => "Required segment is missing",
            InvalidElementFormat => "Element format is invalid",
            InvalidEnvelope => "Invalid envelope structure",

            ValidationError => "Validation error",
            InvalidTransactionType => "Invalid transaction type",
            MissingRequiredElement => "Required element is missing",
            InvalidElementValue => "Element value is invalid",
            InvalidControlNumber => "Control number is invalid",

            RoutingError => "Routing error",
            PartnerNotFound => "Trading partner not found",
            NoRoutingRuleFound => "No routing rule found for transaction",
            InvalidDestination => "Invalid routing destination",

            StorageError => "Storage error",
            BlobNotFound => "Blob not found",
            BlobAccessDenied => "Blob access denied",
            StorageQuotaExceeded => "Storage quota exceeded",

            MessagingError => "Messaging error",
            ServiceBusConnectionError => "Service Bus connection error",
            MessagePublishError => "Message publish error",
            DeadLetterError => "Dead letter processing error",

            MappingError => "Mapping error",
            MappingRuleNotFound => "Mapping rule not found",
            TransformationError => "Transformation error",
            TargetFormatError => "Target format error",

            ConfigurationError => "Configuration error",
            PartnerConfigNotFound => "Partner configuration not found",
            InvalidConfiguration => "Invalid configuration",
            ConfigurationLoadError => "Configuration load error",

            GeneralError => "General error",
            UnexpectedError => "Unexpected error",
            TimeoutError => "Operation timed out",
            AuthenticationError => "Authentication error",
            AuthorizationError => "Authorization error",

            _ => "Unknown error"
        };
    }

    /// <summary>
    /// Determines the error category from the error code
    /// </summary>
    public static string GetCategory(string errorCode)
    {
        return errorCode[..1] switch
        {
            "1" => "Parsing",
            "2" => "Validation",
            "3" => "Routing",
            "4" => "Storage",
            "5" => "Messaging",
            "6" => "Mapping",
            "7" => "Configuration",
            "9" => "General",
            _ => "Unknown"
        };
    }
}
