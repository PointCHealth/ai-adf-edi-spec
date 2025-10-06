using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EDI.EventStore.Migrations.Entities;

[Table("TransactionBatch", Schema = "dbo")]
public class TransactionBatch
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long TransactionBatchID { get; set; }

    [Required]
    public Guid BatchGUID { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(15)]
    public string PartnerCode { get; set; } = null!;

    [Required]
    [MaxLength(10)]
    public string Direction { get; set; } = null!; // 'INBOUND', 'OUTBOUND'

    [Required]
    [MaxLength(10)]
    public string TransactionType { get; set; } = null!; // '834', '270', etc.

    // Source identification
    [MaxLength(500)]
    public string? FileName { get; set; }

    [MaxLength(64)]
    public string? FileHash { get; set; } // SHA256

    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime FileReceivedDate { get; set; }

    [MaxLength(1000)]
    public string? BlobFullUri { get; set; }

    // EDI envelope identifiers
    [MaxLength(15)]
    public string? InterchangeControlNumber { get; set; }

    [MaxLength(15)]
    public string? FunctionalGroupControlNumber { get; set; }

    // Processing metadata
    [Required]
    [MaxLength(20)]
    public string ProcessingStatus { get; set; } = "RECEIVED";

    [Column(TypeName = "datetime2(3)")]
    public DateTime? ProcessingStartedUtc { get; set; }

    [Column(TypeName = "datetime2(3)")]
    public DateTime? ProcessingCompletedUtc { get; set; }

    [Column(TypeName = "nvarchar(max)")]
    public string? ErrorMessage { get; set; }

    // Event correlation
    public long? FirstEventSequence { get; set; }
    public long? LastEventSequence { get; set; }

    [Required]
    public int EventCount { get; set; } = 0;

    // Audit
    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;

    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime ModifiedUtc { get; set; } = DateTime.UtcNow;

    [Timestamp]
    public byte[]? RowVersion { get; set; }

    // Navigation properties
    public virtual ICollection<DomainEvent> DomainEvents { get; set; } = new List<DomainEvent>();
    public virtual ICollection<TransactionHeader> TransactionHeaders { get; set; } = new List<TransactionHeader>();
}
