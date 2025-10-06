using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace EDI.EventStore.Migrations.Data;

/// <summary>
/// Design-time factory for EF Core migrations
/// Used by EF Core tools to create migrations at design time
/// </summary>
public class EventStoreDbContextFactory : IDesignTimeDbContextFactory<EventStoreDbContext>
{
    public EventStoreDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<EventStoreDbContext>();

        // Use a placeholder connection string for design-time
        // Actual connection string will be provided at runtime
        optionsBuilder.UseSqlServer(
            "Server=(localdb)\\mssqllocaldb;Database=EDI_EventStore;Trusted_Connection=True;",
            options => options.MigrationsAssembly("EDI.EventStore.Migrations"));

        return new EventStoreDbContext(optionsBuilder.Options);
    }
}
