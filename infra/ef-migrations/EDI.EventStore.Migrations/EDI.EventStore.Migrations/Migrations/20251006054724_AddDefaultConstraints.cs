using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EDI.EventStore.Migrations.Migrations
{
    /// <inheritdoc />
    public partial class AddDefaultConstraints : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Add default constraints that were missing from initial migration
            // These match the original DACPAC table definitions
            
            migrationBuilder.Sql(@"
                ALTER TABLE dbo.DomainEvent
                ADD CONSTRAINT DF_DomainEvent_EventGUID DEFAULT NEWID() FOR EventGUID;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.DomainEvent
                ADD CONSTRAINT DF_DomainEvent_EventTimestamp DEFAULT SYSUTCDATETIME() FOR EventTimestamp;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.DomainEvent
                ADD CONSTRAINT DF_DomainEvent_CreatedUtc DEFAULT SYSUTCDATETIME() FOR CreatedUtc;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.EventSnapshot
                ADD CONSTRAINT DF_EventSnapshot_SnapshotTimestamp DEFAULT SYSUTCDATETIME() FOR SnapshotTimestamp;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.TransactionBatch
                ADD CONSTRAINT DF_TransactionBatch_BatchGUID DEFAULT NEWID() FOR BatchGUID;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.TransactionBatch
                ADD CONSTRAINT DF_TransactionBatch_CreatedUtc DEFAULT SYSUTCDATETIME() FOR CreatedUtc;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.TransactionBatch
                ADD CONSTRAINT DF_TransactionBatch_ModifiedUtc DEFAULT SYSUTCDATETIME() FOR ModifiedUtc;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.TransactionHeader
                ADD CONSTRAINT DF_TransactionHeader_TransactionGUID DEFAULT NEWID() FOR TransactionGUID;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.TransactionHeader
                ADD CONSTRAINT DF_TransactionHeader_CreatedUtc DEFAULT SYSUTCDATETIME() FOR CreatedUtc;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.TransactionHeader
                ADD CONSTRAINT DF_TransactionHeader_ModifiedUtc DEFAULT SYSUTCDATETIME() FOR ModifiedUtc;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.Member
                ADD CONSTRAINT DF_Member_CreatedUtc DEFAULT SYSUTCDATETIME() FOR CreatedUtc;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.Member
                ADD CONSTRAINT DF_Member_ModifiedUtc DEFAULT SYSUTCDATETIME() FOR ModifiedUtc;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.Enrollment
                ADD CONSTRAINT DF_Enrollment_CreatedUtc DEFAULT SYSUTCDATETIME() FOR CreatedUtc;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.Enrollment
                ADD CONSTRAINT DF_Enrollment_ModifiedUtc DEFAULT SYSUTCDATETIME() FOR ModifiedUtc;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Remove default constraints
            migrationBuilder.Sql("ALTER TABLE dbo.Enrollment DROP CONSTRAINT IF EXISTS DF_Enrollment_ModifiedUtc;");
            migrationBuilder.Sql("ALTER TABLE dbo.Enrollment DROP CONSTRAINT IF EXISTS DF_Enrollment_CreatedUtc;");
            migrationBuilder.Sql("ALTER TABLE dbo.Member DROP CONSTRAINT IF EXISTS DF_Member_ModifiedUtc;");
            migrationBuilder.Sql("ALTER TABLE dbo.Member DROP CONSTRAINT IF EXISTS DF_Member_CreatedUtc;");
            migrationBuilder.Sql("ALTER TABLE dbo.TransactionHeader DROP CONSTRAINT IF EXISTS DF_TransactionHeader_ModifiedUtc;");
            migrationBuilder.Sql("ALTER TABLE dbo.TransactionHeader DROP CONSTRAINT IF EXISTS DF_TransactionHeader_CreatedUtc;");
            migrationBuilder.Sql("ALTER TABLE dbo.TransactionHeader DROP CONSTRAINT IF EXISTS DF_TransactionHeader_TransactionGUID;");
            migrationBuilder.Sql("ALTER TABLE dbo.TransactionBatch DROP CONSTRAINT IF EXISTS DF_TransactionBatch_ModifiedUtc;");
            migrationBuilder.Sql("ALTER TABLE dbo.TransactionBatch DROP CONSTRAINT IF EXISTS DF_TransactionBatch_CreatedUtc;");
            migrationBuilder.Sql("ALTER TABLE dbo.TransactionBatch DROP CONSTRAINT IF EXISTS DF_TransactionBatch_BatchGUID;");
            migrationBuilder.Sql("ALTER TABLE dbo.EventSnapshot DROP CONSTRAINT IF EXISTS DF_EventSnapshot_SnapshotTimestamp;");
            migrationBuilder.Sql("ALTER TABLE dbo.DomainEvent DROP CONSTRAINT IF EXISTS DF_DomainEvent_CreatedUtc;");
            migrationBuilder.Sql("ALTER TABLE dbo.DomainEvent DROP CONSTRAINT IF EXISTS DF_DomainEvent_EventTimestamp;");
            migrationBuilder.Sql("ALTER TABLE dbo.DomainEvent DROP CONSTRAINT IF EXISTS DF_DomainEvent_EventGUID;");
        }
    }
}
