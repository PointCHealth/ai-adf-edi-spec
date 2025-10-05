namespace HealthcareEDI.Core.Interfaces;

/// <summary>
/// Interface for publishing messages to a message broker
/// </summary>
public interface IMessagePublisher
{
    /// <summary>
    /// Publishes a message to a topic or queue
    /// </summary>
    /// <typeparam name="T">Message type</typeparam>
    /// <param name="destination">Topic or queue name</param>
    /// <param name="message">Message payload</param>
    /// <param name="correlationId">Correlation ID for tracking</param>
    /// <param name="cancellationToken">Cancellation token</param>
    Task PublishAsync<T>(
        string destination,
        T message,
        string? correlationId = null,
        CancellationToken cancellationToken = default) where T : class;

    /// <summary>
    /// Publishes multiple messages in a batch
    /// </summary>
    Task PublishBatchAsync<T>(
        string destination,
        IEnumerable<T> messages,
        string? correlationId = null,
        CancellationToken cancellationToken = default) where T : class;
}
