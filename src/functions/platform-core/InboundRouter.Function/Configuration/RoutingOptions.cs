namespace HealthcareEDI.InboundRouter.Configuration;

public class RoutingOptions
{
    public string RoutingTopicName { get; set; } = "transaction-routing";
    public int MaxRetryAttempts { get; set; } = 3;
    public TimeSpan RetryDelay { get; set; } = TimeSpan.FromSeconds(5);
    public Dictionary<string, string> TransactionTypeMapping { get; set; } = new();
}
