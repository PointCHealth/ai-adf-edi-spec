namespace HealthcareEDI.Core.Interfaces;

/// <summary>
/// Interface for storage operations (Blob, File, etc.)
/// </summary>
public interface IStorageService
{
    /// <summary>
    /// Uploads content to storage
    /// </summary>
    Task<string> UploadAsync(
        string containerName,
        string blobName,
        Stream content,
        Dictionary<string, string>? metadata = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Downloads content from storage
    /// </summary>
    Task<Stream> DownloadAsync(
        string containerName,
        string blobName,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Checks if a blob exists
    /// </summary>
    Task<bool> ExistsAsync(
        string containerName,
        string blobName,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Deletes a blob from storage
    /// </summary>
    Task DeleteAsync(
        string containerName,
        string blobName,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Gets blob metadata
    /// </summary>
    Task<Dictionary<string, string>> GetMetadataAsync(
        string containerName,
        string blobName,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Lists blobs in a container with optional prefix
    /// </summary>
    Task<IEnumerable<string>> ListBlobsAsync(
        string containerName,
        string? prefix = null,
        CancellationToken cancellationToken = default);
}
