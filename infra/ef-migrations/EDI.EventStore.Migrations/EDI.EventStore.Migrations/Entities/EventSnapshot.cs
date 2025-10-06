using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EDI.EventStore.Migrations.Entities;

[Table("EventSnapshot", Schema = "dbo")]
public class EventSnapshot
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long SnapshotID { get; set; }

    [Required]
    [MaxLength(50)]
    public string AggregateType { get; set; } = null!;

    [Required]
    [MaxLength(100)]
    public string AggregateID { get; set; } = null!;

    // Snapshot data
    [Required]
    [Column(TypeName = "nvarchar(max)")]
    public string SnapshotData { get; set; } = null!; // JSON

    [Required]
    public int SnapshotVersion { get; set; }

    // Temporal tracking
    [Required]
    public long EventSequence { get; set; }

    [Required]
    [Column(TypeName = "datetime2(3)")]
    public DateTime SnapshotTimestamp { get; set; } = DateTime.UtcNow;
}
