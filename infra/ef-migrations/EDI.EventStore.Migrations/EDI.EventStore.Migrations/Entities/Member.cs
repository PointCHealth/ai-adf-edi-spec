using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EDI.EventStore.Migrations.Entities;

[Table("Member", Schema = "dbo")]
public class Member
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long MemberID { get; set; }

    // Business identifiers
    [Required]
    [MaxLength(50)]
    public string SubscriberID { get; set; } = null!;

    [MaxLength(10)]
    public string? MemberSuffix { get; set; }

    [MaxLength(11)]
    public string? SSN { get; set; }

    // Demographics
    [Required]
    [MaxLength(50)]
    public string FirstName { get; set; } = null!;

    [MaxLength(50)]
    public string? MiddleName { get; set; }

    [Required]
    [MaxLength(50)]
    public string LastName { get; set; } = null!;

    [Required]
    [Column(TypeName = "date")]
    public DateTime DateOfBirth { get; set; }

    [Column(TypeName = "char(1)")]
    public string? Gender { get; set; }

    // Contact information
    [MaxLength(100)]
    public string? AddressLine1 { get; set; }

    [MaxLength(100)]
    public string? AddressLine2 { get; set; }

    [MaxLength(50)]
    public string? City { get; set; }

    [Column(TypeName = "char(2)")]
    public string? State { get; set; }

    [MaxLength(10)]
    public string? ZipCode { get; set; }

    [MaxLength(20)]
    public string? PhoneNumber { get; set; }

    [MaxLength(100)]
    public string? EmailAddress { get; set; }

    // Enrollment status
    [MaxLength(2)]
    public string? RelationshipCode { get; set; }

    [MaxLength(2)]
    public string? EmploymentStatusCode { get; set; }

    // Projection metadata
    [Required]
    public int Version { get; set; } = 1;

    [Required]
    public long LastEventSequence { get; set; }

    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime LastEventTimestamp { get; set; }

    [Required]
    public bool IsActive { get; set; } = true;

    // Audit
    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;

    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime ModifiedUtc { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public virtual ICollection<Enrollment> Enrollments { get; set; } = new List<Enrollment>();
}
