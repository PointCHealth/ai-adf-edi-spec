using Microsoft.EntityFrameworkCore;
using EDI.EventStore.Migrations.Entities;

namespace EDI.EventStore.Migrations.Data;

/// <summary>
/// EventStoreDbContext - EF Core DbContext for Event Store Database
/// Replaces broken Microsoft.Build.Sql DACPAC SDK
/// </summary>
public class EventStoreDbContext : DbContext
{
    public EventStoreDbContext(DbContextOptions<EventStoreDbContext> options)
        : base(options)
    {
    }

    // Tables
    public DbSet<DomainEvent> DomainEvents { get; set; } = null!;
    public DbSet<TransactionBatch> TransactionBatches { get; set; } = null!;
    public DbSet<TransactionHeader> TransactionHeaders { get; set; } = null!;
    public DbSet<Member> Members { get; set; } = null!;
    public DbSet<Enrollment> Enrollments { get; set; } = null!;
    public DbSet<EventSnapshot> EventSnapshots { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configure EventSequence (will be created via raw SQL in migration)
        modelBuilder.HasSequence<long>("EventSequence", "dbo")
            .StartsAt(1)
            .IncrementsBy(1);

        // TransactionBatch configuration
        modelBuilder.Entity<TransactionBatch>(entity =>
        {
            entity.HasIndex(e => e.BatchGUID).IsUnique();
            entity.HasIndex(e => e.FileHash).IsUnique().HasFilter("[FileHash] IS NOT NULL");
            entity.HasIndex(e => new { e.PartnerCode, e.TransactionType, e.FileReceivedDate });
            entity.HasIndex(e => new { e.ProcessingStatus, e.FileReceivedDate });
            entity.HasIndex(e => new { e.InterchangeControlNumber, e.FunctionalGroupControlNumber });

            // Check constraints
            entity.HasCheckConstraint("CHK_TransactionBatch_Direction", 
                "[Direction] IN ('INBOUND', 'OUTBOUND')");
            entity.HasCheckConstraint("CHK_TransactionBatch_Status",
                "[ProcessingStatus] IN ('RECEIVED', 'PROCESSING', 'COMPLETED', 'FAILED', 'REVERSED')");
        });

        // TransactionHeader configuration
        modelBuilder.Entity<TransactionHeader>(entity =>
        {
            entity.HasIndex(e => e.TransactionGUID).IsUnique();
            entity.HasIndex(e => e.TransactionBatchID);
            entity.HasIndex(e => e.TransactionSetControlNumber);

            entity.HasOne(e => e.TransactionBatch)
                .WithMany(b => b.TransactionHeaders)
                .HasForeignKey(e => e.TransactionBatchID)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // DomainEvent configuration
        modelBuilder.Entity<DomainEvent>(entity =>
        {
            entity.HasIndex(e => e.EventGUID).IsUnique();
            entity.HasIndex(e => e.EventSequence).IsUnique();
            entity.HasIndex(e => new { e.AggregateType, e.AggregateID, e.EventSequence });
            entity.HasIndex(e => new { e.EventType, e.EventTimestamp });
            entity.HasIndex(e => new { e.TransactionBatchID, e.EventSequence });
            entity.HasIndex(e => e.CorrelationID);
            entity.HasIndex(e => new { e.EventTimestamp, e.EventSequence });

            entity.HasOne(e => e.TransactionBatch)
                .WithMany(b => b.DomainEvents)
                .HasForeignKey(e => e.TransactionBatchID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.TransactionHeader)
                .WithMany(h => h.DomainEvents)
                .HasForeignKey(e => e.TransactionHeaderID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.ReversedBy)
                .WithMany(e => e.ReversalEvents)
                .HasForeignKey(e => e.ReversedByEventID)
                .OnDelete(DeleteBehavior.Restrict);

            // EventSequence default value via sequence
            entity.Property(e => e.EventSequence)
                .HasDefaultValueSql("NEXT VALUE FOR dbo.EventSequence");
        });

        // Member configuration
        modelBuilder.Entity<Member>(entity =>
        {
            entity.HasIndex(e => e.SubscriberID).IsUnique();
            entity.HasIndex(e => new { e.LastName, e.FirstName, e.DateOfBirth });
        });

        // Enrollment configuration
        modelBuilder.Entity<Enrollment>(entity =>
        {
            entity.HasIndex(e => new { e.MemberID, e.IsActive });
            entity.HasIndex(e => new { e.EffectiveDate, e.TerminationDate });

            entity.HasOne(e => e.Member)
                .WithMany(m => m.Enrollments)
                .HasForeignKey(e => e.MemberID)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // EventSnapshot configuration
        modelBuilder.Entity<EventSnapshot>(entity =>
        {
            entity.HasIndex(e => e.EventSequence);
            entity.HasIndex(e => new { e.AggregateType, e.AggregateID, e.SnapshotVersion }).IsUnique();
        });
    }
}
