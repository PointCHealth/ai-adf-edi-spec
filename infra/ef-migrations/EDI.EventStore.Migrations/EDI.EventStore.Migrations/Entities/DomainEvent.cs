using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EDI.EventStore.Migrations.Entities;

/// <summary>
/// DomainEvent - Event Store Append-Only Table
/// Stores all domain events for event sourcing pattern
/// </summary>
[Table("DomainEvent", Schema = "dbo")]
public class DomainEvent
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long EventID { get; set; }

    [Required]
    public Guid EventGUID { get; set; } = Guid.NewGuid();

    // Source correlation
    [Required]
    public long TransactionBatchID { get; set; }

    public long? TransactionHeaderID { get; set; }

    // Event classification
    [Required]
    [MaxLength(50)]
    public string AggregateType { get; set; } = null!; // 'Member', 'Enrollment', 'Coverage'

    [Required]
    [MaxLength(100)]
    public string AggregateID { get; set; } = null!; // Business key (SubscriberID, MemberID)

    [Required]
    [MaxLength(100)]
    public string EventType { get; set; } = null!; // 'MemberAdded', 'EnrollmentTerminated', etc.

    [Required]
    public int EventVersion { get; set; } = 1;

    // Event payload
    [Required]
    [Column(TypeName = "nvarchar(max)")]
    public string EventData { get; set; } = null!; // JSON

    [Column(TypeName = "nvarchar(max)")]
    public string? EventMetadata { get; set; } // JSON

    // Temporal ordering
    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime EventTimestamp { get; set; } = DateTime.UtcNow;

    [Required]
    public long EventSequence { get; set; } // Will be set by sequence

    // Event characteristics
    [Required]
    public bool IsReversal { get; set; } = false;

    public long? ReversedByEventID { get; set; }

    // Processing metadata
    [Required]
    public Guid CorrelationID { get; set; }

    public Guid? CausationID { get; set; }

    // Audit
    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey(nameof(TransactionBatchID))]
    public virtual TransactionBatch TransactionBatch { get; set; } = null!;

    [ForeignKey(nameof(TransactionHeaderID))]
    public virtual TransactionHeader? TransactionHeader { get; set; }

    [ForeignKey(nameof(ReversedByEventID))]
    public virtual DomainEvent? ReversedBy { get; set; }

    public virtual ICollection<DomainEvent> ReversalEvents { get; set; } = new List<DomainEvent>();
}
