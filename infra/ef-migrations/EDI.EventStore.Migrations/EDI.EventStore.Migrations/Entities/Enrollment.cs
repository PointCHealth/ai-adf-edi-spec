using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EDI.EventStore.Migrations.Entities;

[Table("Enrollment", Schema = "dbo")]
public class Enrollment
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long EnrollmentID { get; set; }

    [Required]
    public long MemberID { get; set; }

    // Enrollment details
    [Required]
    [Column(TypeName = "date")]
    public DateTime EffectiveDate { get; set; }

    [Column(TypeName = "date")]
    public DateTime? TerminationDate { get; set; }

    [Required]
    [MaxLength(3)]
    public string MaintenanceTypeCode { get; set; } = null!;

    [MaxLength(3)]
    public string? MaintenanceReasonCode { get; set; }

    [MaxLength(2)]
    public string? BenefitStatusCode { get; set; }

    // Plan information
    [MaxLength(50)]
    public string? GroupNumber { get; set; }

    [MaxLength(50)]
    public string? PlanIdentifier { get; set; }

    // Status
    [Required]
    public bool IsActive { get; set; } = true;

    // Projection metadata
    [Required]
    public int Version { get; set; } = 1;

    [Required]
    public long LastEventSequence { get; set; }

    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime LastEventTimestamp { get; set; }

    // Audit
    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;

    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime ModifiedUtc { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey(nameof(MemberID))]
    public virtual Member Member { get; set; } = null!;
}
