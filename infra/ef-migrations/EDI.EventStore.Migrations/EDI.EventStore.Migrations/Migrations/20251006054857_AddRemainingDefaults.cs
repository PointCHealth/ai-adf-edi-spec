using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EDI.EventStore.Migrations.Migrations
{
    /// <inheritdoc />
    public partial class AddRemainingDefaults : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Add remaining default constraints for Version and IsActive columns
            
            migrationBuilder.Sql(@"
                ALTER TABLE dbo.Member
                ADD CONSTRAINT DF_Member_Version DEFAULT 1 FOR Version;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.Member
                ADD CONSTRAINT DF_Member_IsActive DEFAULT 1 FOR IsActive;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.Enrollment
                ADD CONSTRAINT DF_Enrollment_Version DEFAULT 1 FOR Version;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.Enrollment
                ADD CONSTRAINT DF_Enrollment_IsActive DEFAULT 1 FOR IsActive;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.DomainEvent
                ADD CONSTRAINT DF_DomainEvent_EventVersion DEFAULT 1 FOR EventVersion;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.DomainEvent
                ADD CONSTRAINT DF_DomainEvent_IsReversal DEFAULT 0 FOR IsReversal;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.TransactionBatch
                ADD CONSTRAINT DF_TransactionBatch_EventCount DEFAULT 0 FOR EventCount;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.TransactionHeader
                ADD CONSTRAINT DF_TransactionHeader_SegmentCount DEFAULT 0 FOR SegmentCount;
            ");

            migrationBuilder.Sql(@"
                ALTER TABLE dbo.TransactionHeader
                ADD CONSTRAINT DF_TransactionHeader_MemberCount DEFAULT 0 FOR MemberCount;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("ALTER TABLE dbo.TransactionHeader DROP CONSTRAINT IF EXISTS DF_TransactionHeader_MemberCount;");
            migrationBuilder.Sql("ALTER TABLE dbo.TransactionHeader DROP CONSTRAINT IF EXISTS DF_TransactionHeader_SegmentCount;");
            migrationBuilder.Sql("ALTER TABLE dbo.TransactionBatch DROP CONSTRAINT IF EXISTS DF_TransactionBatch_EventCount;");
            migrationBuilder.Sql("ALTER TABLE dbo.DomainEvent DROP CONSTRAINT IF EXISTS DF_DomainEvent_IsReversal;");
            migrationBuilder.Sql("ALTER TABLE dbo.DomainEvent DROP CONSTRAINT IF EXISTS DF_DomainEvent_EventVersion;");
            migrationBuilder.Sql("ALTER TABLE dbo.Enrollment DROP CONSTRAINT IF EXISTS DF_Enrollment_IsActive;");
            migrationBuilder.Sql("ALTER TABLE dbo.Enrollment DROP CONSTRAINT IF EXISTS DF_Enrollment_Version;");
            migrationBuilder.Sql("ALTER TABLE dbo.Member DROP CONSTRAINT IF EXISTS DF_Member_IsActive;");
            migrationBuilder.Sql("ALTER TABLE dbo.Member DROP CONSTRAINT IF EXISTS DF_Member_Version;");
        }
    }
}
