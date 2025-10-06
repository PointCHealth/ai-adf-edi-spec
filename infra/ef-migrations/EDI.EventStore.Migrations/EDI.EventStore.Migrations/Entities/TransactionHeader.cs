using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EDI.EventStore.Migrations.Entities;

[Table("TransactionHeader", Schema = "dbo")]
public class TransactionHeader
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long TransactionHeaderID { get; set; }

    [Required]
    public Guid TransactionGUID { get; set; } = Guid.NewGuid();

    [Required]
    public long TransactionBatchID { get; set; }

    // EDI identifiers
    [Required]
    [MaxLength(15)]
    public string TransactionSetControlNumber { get; set; } = null!;

    [MaxLength(10)]
    public string? PurposeCode { get; set; } // '00' Original, '05' Replace

    [MaxLength(50)]
    public string? ReferenceIdentification { get; set; }

    [Column(TypeName = "date")]
    public DateTime? TransactionDate { get; set; }

    // Processing metadata
    [Required]
    public int SegmentCount { get; set; } = 0;

    [Required]
    public int MemberCount { get; set; } = 0;

    [Required]
    [MaxLength(20)]
    public string ProcessingStatus { get; set; } = "RECEIVED";

    // Event correlation
    public long? FirstEventSequence { get; set; }
    public long? LastEventSequence { get; set; }

    // Audit
    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;

    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime ModifiedUtc { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey(nameof(TransactionBatchID))]
    public virtual TransactionBatch TransactionBatch { get; set; } = null!;

    public virtual ICollection<DomainEvent> DomainEvents { get; set; } = new List<DomainEvent>();
}
