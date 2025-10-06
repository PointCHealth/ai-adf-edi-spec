using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EDI.EventStore.Migrations.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "dbo");

            migrationBuilder.CreateSequence(
                name: "EventSequence",
                schema: "dbo");

            migrationBuilder.CreateTable(
                name: "EventSnapshot",
                schema: "dbo",
                columns: table => new
                {
                    SnapshotID = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    AggregateType = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    AggregateID = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    SnapshotData = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    SnapshotVersion = table.Column<int>(type: "int", nullable: false),
                    EventSequence = table.Column<long>(type: "bigint", nullable: false),
                    SnapshotTimestamp = table.Column<DateTime>(type: "datetime2(3)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EventSnapshot", x => x.SnapshotID);
                });

            migrationBuilder.CreateTable(
                name: "Member",
                schema: "dbo",
                columns: table => new
                {
                    MemberID = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    SubscriberID = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    MemberSuffix = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: true),
                    SSN = table.Column<string>(type: "nvarchar(11)", maxLength: 11, nullable: true),
                    FirstName = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    MiddleName = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    LastName = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    DateOfBirth = table.Column<DateTime>(type: "date", nullable: false),
                    Gender = table.Column<string>(type: "char(1)", nullable: true),
                    AddressLine1 = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    AddressLine2 = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    City = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    State = table.Column<string>(type: "char(2)", nullable: true),
                    ZipCode = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: true),
                    PhoneNumber = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    EmailAddress = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    RelationshipCode = table.Column<string>(type: "nvarchar(2)", maxLength: 2, nullable: true),
                    EmploymentStatusCode = table.Column<string>(type: "nvarchar(2)", maxLength: 2, nullable: true),
                    Version = table.Column<int>(type: "int", nullable: false),
                    LastEventSequence = table.Column<long>(type: "bigint", nullable: false),
                    LastEventTimestamp = table.Column<DateTime>(type: "datetime2(3)", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedUtc = table.Column<DateTime>(type: "datetime2(3)", nullable: false),
                    ModifiedUtc = table.Column<DateTime>(type: "datetime2(3)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Member", x => x.MemberID);
                });

            migrationBuilder.CreateTable(
                name: "TransactionBatch",
                schema: "dbo",
                columns: table => new
                {
                    TransactionBatchID = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    BatchGUID = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PartnerCode = table.Column<string>(type: "nvarchar(15)", maxLength: 15, nullable: false),
                    Direction = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    TransactionType = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    FileName = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    FileHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    FileReceivedDate = table.Column<DateTime>(type: "datetime2(3)", nullable: false),
                    BlobFullUri = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    InterchangeControlNumber = table.Column<string>(type: "nvarchar(15)", maxLength: 15, nullable: true),
                    FunctionalGroupControlNumber = table.Column<string>(type: "nvarchar(15)", maxLength: 15, nullable: true),
                    ProcessingStatus = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    ProcessingStartedUtc = table.Column<DateTime>(type: "datetime2(3)", nullable: true),
                    ProcessingCompletedUtc = table.Column<DateTime>(type: "datetime2(3)", nullable: true),
                    ErrorMessage = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    FirstEventSequence = table.Column<long>(type: "bigint", nullable: true),
                    LastEventSequence = table.Column<long>(type: "bigint", nullable: true),
                    EventCount = table.Column<int>(type: "int", nullable: false),
                    CreatedUtc = table.Column<DateTime>(type: "datetime2(3)", nullable: false),
                    ModifiedUtc = table.Column<DateTime>(type: "datetime2(3)", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TransactionBatch", x => x.TransactionBatchID);
                    table.CheckConstraint("CHK_TransactionBatch_Direction", "[Direction] IN ('INBOUND', 'OUTBOUND')");
                    table.CheckConstraint("CHK_TransactionBatch_Status", "[ProcessingStatus] IN ('RECEIVED', 'PROCESSING', 'COMPLETED', 'FAILED', 'REVERSED')");
                });

            migrationBuilder.CreateTable(
                name: "Enrollment",
                schema: "dbo",
                columns: table => new
                {
                    EnrollmentID = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    MemberID = table.Column<long>(type: "bigint", nullable: false),
                    EffectiveDate = table.Column<DateTime>(type: "date", nullable: false),
                    TerminationDate = table.Column<DateTime>(type: "date", nullable: true),
                    MaintenanceTypeCode = table.Column<string>(type: "nvarchar(3)", maxLength: 3, nullable: false),
                    MaintenanceReasonCode = table.Column<string>(type: "nvarchar(3)", maxLength: 3, nullable: true),
                    BenefitStatusCode = table.Column<string>(type: "nvarchar(2)", maxLength: 2, nullable: true),
                    GroupNumber = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    PlanIdentifier = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    Version = table.Column<int>(type: "int", nullable: false),
                    LastEventSequence = table.Column<long>(type: "bigint", nullable: false),
                    LastEventTimestamp = table.Column<DateTime>(type: "datetime2(3)", nullable: false),
                    CreatedUtc = table.Column<DateTime>(type: "datetime2(3)", nullable: false),
                    ModifiedUtc = table.Column<DateTime>(type: "datetime2(3)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Enrollment", x => x.EnrollmentID);
                    table.ForeignKey(
                        name: "FK_Enrollment_Member_MemberID",
                        column: x => x.MemberID,
                        principalSchema: "dbo",
                        principalTable: "Member",
                        principalColumn: "MemberID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "TransactionHeader",
                schema: "dbo",
                columns: table => new
                {
                    TransactionHeaderID = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TransactionGUID = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TransactionBatchID = table.Column<long>(type: "bigint", nullable: false),
                    TransactionSetControlNumber = table.Column<string>(type: "nvarchar(15)", maxLength: 15, nullable: false),
                    PurposeCode = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: true),
                    ReferenceIdentification = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    TransactionDate = table.Column<DateTime>(type: "date", nullable: true),
                    SegmentCount = table.Column<int>(type: "int", nullable: false),
                    MemberCount = table.Column<int>(type: "int", nullable: false),
                    ProcessingStatus = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    FirstEventSequence = table.Column<long>(type: "bigint", nullable: true),
                    LastEventSequence = table.Column<long>(type: "bigint", nullable: true),
                    CreatedUtc = table.Column<DateTime>(type: "datetime2(3)", nullable: false),
                    ModifiedUtc = table.Column<DateTime>(type: "datetime2(3)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TransactionHeader", x => x.TransactionHeaderID);
                    table.ForeignKey(
                        name: "FK_TransactionHeader_TransactionBatch_TransactionBatchID",
                        column: x => x.TransactionBatchID,
                        principalSchema: "dbo",
                        principalTable: "TransactionBatch",
                        principalColumn: "TransactionBatchID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "DomainEvent",
                schema: "dbo",
                columns: table => new
                {
                    EventID = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    EventGUID = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TransactionBatchID = table.Column<long>(type: "bigint", nullable: false),
                    TransactionHeaderID = table.Column<long>(type: "bigint", nullable: true),
                    AggregateType = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    AggregateID = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    EventType = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    EventVersion = table.Column<int>(type: "int", nullable: false),
                    EventData = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    EventMetadata = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    EventTimestamp = table.Column<DateTime>(type: "datetime2(3)", nullable: false),
                    EventSequence = table.Column<long>(type: "bigint", nullable: false, defaultValueSql: "NEXT VALUE FOR dbo.EventSequence"),
                    IsReversal = table.Column<bool>(type: "bit", nullable: false),
                    ReversedByEventID = table.Column<long>(type: "bigint", nullable: true),
                    CorrelationID = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CausationID = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedUtc = table.Column<DateTime>(type: "datetime2(3)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DomainEvent", x => x.EventID);
                    table.ForeignKey(
                        name: "FK_DomainEvent_DomainEvent_ReversedByEventID",
                        column: x => x.ReversedByEventID,
                        principalSchema: "dbo",
                        principalTable: "DomainEvent",
                        principalColumn: "EventID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DomainEvent_TransactionBatch_TransactionBatchID",
                        column: x => x.TransactionBatchID,
                        principalSchema: "dbo",
                        principalTable: "TransactionBatch",
                        principalColumn: "TransactionBatchID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DomainEvent_TransactionHeader_TransactionHeaderID",
                        column: x => x.TransactionHeaderID,
                        principalSchema: "dbo",
                        principalTable: "TransactionHeader",
                        principalColumn: "TransactionHeaderID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DomainEvent_AggregateType_AggregateID_EventSequence",
                schema: "dbo",
                table: "DomainEvent",
                columns: new[] { "AggregateType", "AggregateID", "EventSequence" });

            migrationBuilder.CreateIndex(
                name: "IX_DomainEvent_CorrelationID",
                schema: "dbo",
                table: "DomainEvent",
                column: "CorrelationID");

            migrationBuilder.CreateIndex(
                name: "IX_DomainEvent_EventGUID",
                schema: "dbo",
                table: "DomainEvent",
                column: "EventGUID",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DomainEvent_EventSequence",
                schema: "dbo",
                table: "DomainEvent",
                column: "EventSequence",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DomainEvent_EventTimestamp_EventSequence",
                schema: "dbo",
                table: "DomainEvent",
                columns: new[] { "EventTimestamp", "EventSequence" });

            migrationBuilder.CreateIndex(
                name: "IX_DomainEvent_EventType_EventTimestamp",
                schema: "dbo",
                table: "DomainEvent",
                columns: new[] { "EventType", "EventTimestamp" });

            migrationBuilder.CreateIndex(
                name: "IX_DomainEvent_ReversedByEventID",
                schema: "dbo",
                table: "DomainEvent",
                column: "ReversedByEventID");

            migrationBuilder.CreateIndex(
                name: "IX_DomainEvent_TransactionBatchID_EventSequence",
                schema: "dbo",
                table: "DomainEvent",
                columns: new[] { "TransactionBatchID", "EventSequence" });

            migrationBuilder.CreateIndex(
                name: "IX_DomainEvent_TransactionHeaderID",
                schema: "dbo",
                table: "DomainEvent",
                column: "TransactionHeaderID");

            migrationBuilder.CreateIndex(
                name: "IX_Enrollment_EffectiveDate_TerminationDate",
                schema: "dbo",
                table: "Enrollment",
                columns: new[] { "EffectiveDate", "TerminationDate" });

            migrationBuilder.CreateIndex(
                name: "IX_Enrollment_MemberID_IsActive",
                schema: "dbo",
                table: "Enrollment",
                columns: new[] { "MemberID", "IsActive" });

            migrationBuilder.CreateIndex(
                name: "IX_EventSnapshot_AggregateType_AggregateID_SnapshotVersion",
                schema: "dbo",
                table: "EventSnapshot",
                columns: new[] { "AggregateType", "AggregateID", "SnapshotVersion" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_EventSnapshot_EventSequence",
                schema: "dbo",
                table: "EventSnapshot",
                column: "EventSequence");

            migrationBuilder.CreateIndex(
                name: "IX_Member_LastName_FirstName_DateOfBirth",
                schema: "dbo",
                table: "Member",
                columns: new[] { "LastName", "FirstName", "DateOfBirth" });

            migrationBuilder.CreateIndex(
                name: "IX_Member_SubscriberID",
                schema: "dbo",
                table: "Member",
                column: "SubscriberID",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TransactionBatch_BatchGUID",
                schema: "dbo",
                table: "TransactionBatch",
                column: "BatchGUID",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TransactionBatch_FileHash",
                schema: "dbo",
                table: "TransactionBatch",
                column: "FileHash",
                unique: true,
                filter: "[FileHash] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_TransactionBatch_InterchangeControlNumber_FunctionalGroupControlNumber",
                schema: "dbo",
                table: "TransactionBatch",
                columns: new[] { "InterchangeControlNumber", "FunctionalGroupControlNumber" });

            migrationBuilder.CreateIndex(
                name: "IX_TransactionBatch_PartnerCode_TransactionType_FileReceivedDate",
                schema: "dbo",
                table: "TransactionBatch",
                columns: new[] { "PartnerCode", "TransactionType", "FileReceivedDate" });

            migrationBuilder.CreateIndex(
                name: "IX_TransactionBatch_ProcessingStatus_FileReceivedDate",
                schema: "dbo",
                table: "TransactionBatch",
                columns: new[] { "ProcessingStatus", "FileReceivedDate" });

            migrationBuilder.CreateIndex(
                name: "IX_TransactionHeader_TransactionBatchID",
                schema: "dbo",
                table: "TransactionHeader",
                column: "TransactionBatchID");

            migrationBuilder.CreateIndex(
                name: "IX_TransactionHeader_TransactionGUID",
                schema: "dbo",
                table: "TransactionHeader",
                column: "TransactionGUID",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TransactionHeader_TransactionSetControlNumber",
                schema: "dbo",
                table: "TransactionHeader",
                column: "TransactionSetControlNumber");

            // =============================================
            // Create Views
            // =============================================

            migrationBuilder.Sql(@"
CREATE VIEW dbo.vw_EventStream
AS
    SELECT
        [DomainEvent].[EventID],
        [DomainEvent].[EventGUID],
        [DomainEvent].[EventSequence],
        [DomainEvent].[EventTimestamp],
        [DomainEvent].[AggregateType],
        [DomainEvent].[AggregateID],
        [DomainEvent].[EventType],
        [DomainEvent].[EventVersion],
        [DomainEvent].[EventData],
        [DomainEvent].[EventMetadata],
        [DomainEvent].[IsReversal],
        [DomainEvent].[CorrelationID],
        [DomainEvent].[CausationID],
        [TransactionBatch].[BatchGUID],
        [TransactionBatch].[PartnerCode],
        [TransactionBatch].[Direction],
        [TransactionBatch].[TransactionType],
        [TransactionBatch].[FileName],
        [TransactionBatch].[InterchangeControlNumber],
        [TransactionHeader].[TransactionSetControlNumber],
        [TransactionHeader].[PurposeCode]
    FROM [DomainEvent]
    INNER JOIN [TransactionBatch] ON [DomainEvent].[TransactionBatchID] = [TransactionBatch].[TransactionBatchID]
    LEFT JOIN [TransactionHeader] ON [DomainEvent].[TransactionHeaderID] = [TransactionHeader].[TransactionHeaderID];
");

            migrationBuilder.Sql(@"
CREATE VIEW dbo.vw_ActiveEnrollments
AS
    SELECT
        [Member].[MemberID],
        [Member].[SubscriberID],
        [Member].[FirstName],
        [Member].[MiddleName],
        [Member].[LastName],
        [Member].[DateOfBirth],
        [Member].[Gender],
        [Member].[RelationshipCode],
        [Enrollment].[EnrollmentID],
        [Enrollment].[EffectiveDate],
        [Enrollment].[TerminationDate],
        [Enrollment].[MaintenanceTypeCode],
        [Enrollment].[BenefitStatusCode],
        [Enrollment].[GroupNumber],
        [Enrollment].[PlanIdentifier],
        [Enrollment].[LastEventSequence] AS EnrollmentLastEventSequence,
        [Enrollment].[LastEventTimestamp] AS EnrollmentLastEventTimestamp,
        [Member].[LastEventSequence] AS MemberLastEventSequence,
        [Member].[LastEventTimestamp] AS MemberLastEventTimestamp
    FROM [Enrollment]
    INNER JOIN [Member] ON [Enrollment].[MemberID] = [Member].[MemberID]
    WHERE [Enrollment].[IsActive] = 1 AND [Member].[IsActive] = 1;
");

            migrationBuilder.Sql(@"
CREATE VIEW dbo.vw_BatchProcessingSummary
AS
    SELECT
        [TransactionBatch].[BatchGUID],
        [TransactionBatch].[PartnerCode],
        [TransactionBatch].[Direction],
        [TransactionBatch].[TransactionType],
        [TransactionBatch].[FileName],
        [TransactionBatch].[FileReceivedDate],
        [TransactionBatch].[ProcessingStatus],
        [TransactionBatch].[ProcessingStartedUtc],
        DATEDIFF(SECOND, [TransactionBatch].[ProcessingStartedUtc], GETUTCDATE()) AS ProcessingDurationSeconds,
        COUNT(DISTINCT [TransactionHeader].[TransactionHeaderID]) AS TransactionCount,
        [TransactionBatch].[InterchangeControlNumber],
        [TransactionBatch].[FunctionalGroupControlNumber]
    FROM [TransactionBatch]
    LEFT JOIN [TransactionHeader] ON [TransactionBatch].[TransactionBatchID] = [TransactionHeader].[TransactionBatchID]
    GROUP BY
        [TransactionBatch].[BatchGUID],
        [TransactionBatch].[PartnerCode],
        [TransactionBatch].[Direction],
        [TransactionBatch].[TransactionType],
        [TransactionBatch].[FileName],
        [TransactionBatch].[FileReceivedDate],
        [TransactionBatch].[ProcessingStatus],
        [TransactionBatch].[ProcessingStartedUtc],
        [TransactionBatch].[InterchangeControlNumber],
        [TransactionBatch].[FunctionalGroupControlNumber];
");

            migrationBuilder.Sql(@"
CREATE VIEW dbo.vw_MemberEventHistory
AS
    SELECT
        [Member].[MemberID],
        [Member].[SubscriberID],
        [Member].[FirstName],
        [Member].[LastName],
        [DomainEvent].[EventID],
        [DomainEvent].[EventSequence],
        [DomainEvent].[EventTimestamp],
        [DomainEvent].[EventType],
        [DomainEvent].[EventVersion],
        [DomainEvent].[EventData],
        [DomainEvent].[IsReversal],
        [TransactionBatch].[PartnerCode],
        [TransactionBatch].[FileName],
        [TransactionBatch].[FileReceivedDate],
        [DomainEvent].[CorrelationID]
    FROM [Member]
    INNER JOIN [DomainEvent] ON [Member].[SubscriberID] = [DomainEvent].[AggregateID] AND [DomainEvent].[AggregateType] = 'Member'
    INNER JOIN [TransactionBatch] ON [DomainEvent].[TransactionBatchID] = [TransactionBatch].[TransactionBatchID];
");

            migrationBuilder.Sql(@"
CREATE VIEW dbo.vw_ProjectionLag
AS
    SELECT
        'Member' AS AggregateType,
        [Member].[SubscriberID] AS AggregateID,
        [Member].[LastEventSequence] AS ProjectionSequence,
        MAX([DomainEvent].[EventSequence]) AS LatestEventSequence,
        MAX([DomainEvent].[EventSequence]) - [Member].[LastEventSequence] AS SequenceLag,
        [Member].[LastEventTimestamp] AS ProjectionTimestamp,
        MAX([DomainEvent].[EventTimestamp]) AS LatestEventTimestamp
    FROM [Member]
    INNER JOIN [DomainEvent] ON [Member].[SubscriberID] = [DomainEvent].[AggregateID]
        AND [DomainEvent].[AggregateType] = 'Member'
        AND [DomainEvent].[EventSequence] > [Member].[LastEventSequence]
    GROUP BY [Member].[SubscriberID], [Member].[LastEventSequence], [Member].[LastEventTimestamp]
    
    UNION ALL

    SELECT
        'Enrollment' AS AggregateType,
        [Enrollment].[MemberID] AS AggregateID,
        [Enrollment].[LastEventSequence] AS ProjectionSequence,
        MAX([DomainEvent].[EventSequence]) AS LatestEventSequence,
        MAX([DomainEvent].[EventSequence]) - [Enrollment].[LastEventSequence] AS SequenceLag,
        [Enrollment].[LastEventTimestamp] AS ProjectionTimestamp,
        MAX([DomainEvent].[EventTimestamp]) AS LatestEventTimestamp
    FROM [Enrollment]
    INNER JOIN [Member] ON [Enrollment].[MemberID] = [Member].[MemberID]
    INNER JOIN [DomainEvent] ON [Member].[SubscriberID] = [DomainEvent].[AggregateID]
        AND [DomainEvent].[AggregateType] = 'Enrollment'
        AND [DomainEvent].[EventSequence] > [Enrollment].[LastEventSequence]
    GROUP BY [Enrollment].[MemberID], [Enrollment].[LastEventSequence], [Enrollment].[LastEventTimestamp];
");

            migrationBuilder.Sql(@"
CREATE VIEW dbo.vw_EventTypeStatistics
AS
    SELECT
        EventType,
        AggregateType,
        COUNT(*) AS EventCount,
        MIN(EventTimestamp) AS FirstEventTimestamp,
        MAX(EventTimestamp) AS LastEventTimestamp,
        COUNT(DISTINCT AggregateID) AS UniqueAggregates,
        SUM(CASE WHEN IsReversal = 1 THEN 1 ELSE 0 END) AS ReversalCount
    FROM dbo.DomainEvent
    GROUP BY EventType, AggregateType;
");

            // =============================================
            // Create Stored Procedures
            // =============================================

            migrationBuilder.Sql(@"
CREATE PROCEDURE dbo.usp_AppendEvent
    @TransactionBatchID     BIGINT,
    @TransactionHeaderID    BIGINT = NULL,
    @AggregateType          VARCHAR(50),
    @AggregateID            VARCHAR(100),
    @EventType              VARCHAR(100),
    @EventVersion           INT = 1,
    @EventData              NVARCHAR(MAX),
    @EventMetadata          NVARCHAR(MAX) = NULL,
    @CorrelationID          UNIQUEIDENTIFIER,
    @CausationID            UNIQUEIDENTIFIER = NULL,
    @IsReversal             BIT = 0,
    @EventID                BIGINT OUTPUT,
    @EventSequence          BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Validate JSON
    IF NOT ISJSON(@EventData) = 1
    BEGIN
        THROW 50001, 'EventData is not valid JSON', 1;
    END;

    IF @EventMetadata IS NOT NULL AND NOT ISJSON(@EventMetadata) = 1
    BEGIN
        THROW 50002, 'EventMetadata is not valid JSON', 1;
    END;

    -- Insert event
    INSERT INTO dbo.DomainEvent (
        TransactionBatchID,
        TransactionHeaderID,
        AggregateType,
        AggregateID,
        EventType,
        EventVersion,
        EventData,
        EventMetadata,
        IsReversal,
        CorrelationID,
        CausationID
    )
    VALUES (
        @TransactionBatchID,
        @TransactionHeaderID,
        @AggregateType,
        @AggregateID,
        @EventType,
        @EventVersion,
        @EventData,
        @EventMetadata,
        @IsReversal,
        @CorrelationID,
        @CausationID
    );

    -- Return generated values
    SELECT
        @EventID = EventID,
        @EventSequence = EventSequence
    FROM dbo.DomainEvent
    WHERE EventID = SCOPE_IDENTITY();

    -- Update batch event count and range
    UPDATE dbo.TransactionBatch
    SET
        EventCount = EventCount + 1,
        FirstEventSequence = COALESCE(FirstEventSequence, @EventSequence),
        LastEventSequence = @EventSequence,
        ModifiedUtc = SYSUTCDATETIME()
    WHERE TransactionBatchID = @TransactionBatchID;

    RETURN 0;
END;
");

            migrationBuilder.Sql(@"
CREATE PROCEDURE dbo.usp_GetEventStream
    @AggregateType          VARCHAR(50),
    @AggregateID            VARCHAR(100),
    @FromSequence           BIGINT = 0,
    @ToSequence             BIGINT = NULL,
    @IncludeReversals       BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.EventID,
        e.EventGUID,
        e.EventSequence,
        e.EventTimestamp,
        e.AggregateType,
        e.AggregateID,
        e.EventType,
        e.EventVersion,
        e.EventData,
        e.EventMetadata,
        e.IsReversal,
        e.ReversedByEventID,
        e.CorrelationID,
        e.CausationID,
        e.TransactionBatchID,
        e.TransactionHeaderID
    FROM dbo.DomainEvent e
    WHERE e.AggregateType = @AggregateType
      AND e.AggregateID = @AggregateID
      AND e.EventSequence >= @FromSequence
      AND (@ToSequence IS NULL OR e.EventSequence <= @ToSequence)
      AND (@IncludeReversals = 1 OR e.IsReversal = 0)
    ORDER BY e.EventSequence ASC;
END;
");

            migrationBuilder.Sql(@"
CREATE PROCEDURE dbo.usp_GetLatestSnapshot
    @AggregateType          VARCHAR(50),
    @AggregateID            VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        SnapshotID,
        AggregateType,
        AggregateID,
        SnapshotData,
        SnapshotVersion,
        EventSequence,
        SnapshotTimestamp
    FROM dbo.EventSnapshot
    WHERE AggregateType = @AggregateType
      AND AggregateID = @AggregateID
    ORDER BY SnapshotVersion DESC;
END;
");

            migrationBuilder.Sql(@"
CREATE PROCEDURE dbo.usp_CreateSnapshot
    @AggregateType          VARCHAR(50),
    @AggregateID            VARCHAR(100),
    @SnapshotData           NVARCHAR(MAX),
    @EventSequence          BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CurrentVersion INT;

    -- Get current version
    SELECT @CurrentVersion = ISNULL(MAX(SnapshotVersion), 0)
    FROM dbo.EventSnapshot
    WHERE AggregateType = @AggregateType
      AND AggregateID = @AggregateID;

    -- Insert new snapshot
    INSERT INTO dbo.EventSnapshot (
        AggregateType,
        AggregateID,
        SnapshotData,
        SnapshotVersion,
        EventSequence
    )
    VALUES (
        @AggregateType,
        @AggregateID,
        @SnapshotData,
        @CurrentVersion + 1,
        @EventSequence
    );

    -- Clean up old snapshots (keep last 3)
    DELETE FROM dbo.EventSnapshot
    WHERE AggregateType = @AggregateType
      AND AggregateID = @AggregateID
      AND SnapshotVersion <= @CurrentVersion - 2;

    RETURN 0;
END;
");

            migrationBuilder.Sql(@"
CREATE PROCEDURE dbo.usp_UpdateMemberProjection
    @SubscriberID           VARCHAR(50),
    @FirstName              NVARCHAR(50),
    @MiddleName             NVARCHAR(50) = NULL,
    @LastName               NVARCHAR(50),
    @DateOfBirth            DATE,
    @Gender                 CHAR(1) = NULL,
    @SSN                    VARCHAR(11) = NULL,
    @RelationshipCode       VARCHAR(2) = NULL,
    @AddressLine1           NVARCHAR(100) = NULL,
    @AddressLine2           NVARCHAR(100) = NULL,
    @City                   NVARCHAR(50) = NULL,
    @State                  CHAR(2) = NULL,
    @ZipCode                VARCHAR(10) = NULL,
    @PhoneNumber            VARCHAR(20) = NULL,
    @EmailAddress           NVARCHAR(100) = NULL,
    @LastEventSequence      BIGINT,
    @LastEventTimestamp     DATETIME2(3),
    @IsActive               BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CurrentVersion INT;
    DECLARE @MemberID BIGINT;

    -- Check if member exists
    SELECT @MemberID = MemberID, @CurrentVersion = Version
    FROM dbo.Member WITH (UPDLOCK)
    WHERE SubscriberID = @SubscriberID;

    IF @MemberID IS NULL
    BEGIN
        -- Insert new member
        INSERT INTO dbo.Member (
            SubscriberID, FirstName, MiddleName, LastName, DateOfBirth, Gender,
            SSN, RelationshipCode, AddressLine1, AddressLine2, City, State, ZipCode,
            PhoneNumber, EmailAddress, LastEventSequence, LastEventTimestamp, IsActive
        )
        VALUES (
            @SubscriberID, @FirstName, @MiddleName, @LastName, @DateOfBirth, @Gender,
            @SSN, @RelationshipCode, @AddressLine1, @AddressLine2, @City, @State, @ZipCode,
            @PhoneNumber, @EmailAddress, @LastEventSequence, @LastEventTimestamp, @IsActive
        );

        SET @MemberID = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        -- Update existing member with optimistic concurrency
        UPDATE dbo.Member
        SET
            FirstName = @FirstName,
            MiddleName = @MiddleName,
            LastName = @LastName,
            DateOfBirth = @DateOfBirth,
            Gender = @Gender,
            SSN = @SSN,
            RelationshipCode = @RelationshipCode,
            AddressLine1 = @AddressLine1,
            AddressLine2 = @AddressLine2,
            City = @City,
            State = @State,
            ZipCode = @ZipCode,
            PhoneNumber = @PhoneNumber,
            EmailAddress = @EmailAddress,
            Version = Version + 1,
            LastEventSequence = @LastEventSequence,
            LastEventTimestamp = @LastEventTimestamp,
            IsActive = @IsActive,
            ModifiedUtc = SYSUTCDATETIME()
        WHERE MemberID = @MemberID
          AND LastEventSequence < @LastEventSequence; -- Only update if newer

        IF @@ROWCOUNT = 0
        BEGIN
            -- Event already processed or out of order
            RETURN 1; -- Idempotent success
        END;
    END;

    RETURN 0;
END;
");

            migrationBuilder.Sql(@"
CREATE PROCEDURE dbo.usp_UpdateEnrollmentProjection
    @SubscriberID           VARCHAR(50),
    @EffectiveDate          DATE,
    @TerminationDate        DATE = NULL,
    @MaintenanceTypeCode    VARCHAR(3),
    @MaintenanceReasonCode  VARCHAR(3) = NULL,
    @BenefitStatusCode      VARCHAR(2) = NULL,
    @GroupNumber            VARCHAR(50) = NULL,
    @PlanIdentifier         VARCHAR(50) = NULL,
    @LastEventSequence      BIGINT,
    @LastEventTimestamp     DATETIME2(3)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MemberID BIGINT;
    DECLARE @EnrollmentID BIGINT;
    DECLARE @IsActive BIT;

    -- Get MemberID
    SELECT @MemberID = MemberID
    FROM dbo.Member
    WHERE SubscriberID = @SubscriberID;

    IF @MemberID IS NULL
    BEGIN
        THROW 50003, 'Member not found for enrollment update', 1;
    END;

    -- Determine active status based on maintenance type
    SET @IsActive = CASE
        WHEN @MaintenanceTypeCode IN ('024', '025') THEN 0 -- Termination or cancellation
        WHEN @TerminationDate IS NOT NULL AND @TerminationDate <= CAST(SYSUTCDATETIME() AS DATE) THEN 0
        ELSE 1
    END;

    -- Check for existing enrollment
    SELECT @EnrollmentID = EnrollmentID
    FROM dbo.Enrollment WITH (UPDLOCK)
    WHERE MemberID = @MemberID
      AND EffectiveDate = @EffectiveDate;

    IF @EnrollmentID IS NULL
    BEGIN
        -- Insert new enrollment
        INSERT INTO dbo.Enrollment (
            MemberID, EffectiveDate, TerminationDate, MaintenanceTypeCode,
            MaintenanceReasonCode, BenefitStatusCode, GroupNumber, PlanIdentifier,
            IsActive, LastEventSequence, LastEventTimestamp
        )
        VALUES (
            @MemberID, @EffectiveDate, @TerminationDate, @MaintenanceTypeCode,
            @MaintenanceReasonCode, @BenefitStatusCode, @GroupNumber, @PlanIdentifier,
            @IsActive, @LastEventSequence, @LastEventTimestamp
        );
    END
    ELSE
    BEGIN
        -- Update existing enrollment
        UPDATE dbo.Enrollment
        SET
            TerminationDate = @TerminationDate,
            MaintenanceTypeCode = @MaintenanceTypeCode,
            MaintenanceReasonCode = @MaintenanceReasonCode,
            BenefitStatusCode = @BenefitStatusCode,
            GroupNumber = @GroupNumber,
            PlanIdentifier = @PlanIdentifier,
            IsActive = @IsActive,
            Version = Version + 1,
            LastEventSequence = @LastEventSequence,
            LastEventTimestamp = @LastEventTimestamp,
            ModifiedUtc = SYSUTCDATETIME()
        WHERE EnrollmentID = @EnrollmentID
          AND LastEventSequence < @LastEventSequence;
    END;

    RETURN 0;
END;
");

            migrationBuilder.Sql(@"
CREATE PROCEDURE dbo.usp_ReverseBatch
    @TransactionBatchID     BIGINT,
    @Reason                 NVARCHAR(500),
    @ReversalCorrelationID  UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OriginalEventID BIGINT;
    DECLARE @EventCursor CURSOR;

    BEGIN TRANSACTION;

    -- Mark batch as reversed
    UPDATE dbo.TransactionBatch
    SET
        ProcessingStatus = 'REVERSED',
        ErrorMessage = @Reason,
        ModifiedUtc = SYSUTCDATETIME()
    WHERE TransactionBatchID = @TransactionBatchID;

    -- Create reversal events for each original event
    SET @EventCursor = CURSOR FOR
        SELECT EventID
        FROM dbo.DomainEvent
        WHERE TransactionBatchID = @TransactionBatchID
          AND IsReversal = 0
        ORDER BY EventSequence ASC; -- Reverse in original order

    OPEN @EventCursor;
    FETCH NEXT FROM @EventCursor INTO @OriginalEventID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Create reversal event
        INSERT INTO dbo.DomainEvent (
            TransactionBatchID,
            TransactionHeaderID,
            AggregateType,
            AggregateID,
            EventType,
            EventVersion,
            EventData,
            EventMetadata,
            IsReversal,
            ReversedByEventID,
            CorrelationID
        )
        SELECT
            TransactionBatchID,
            TransactionHeaderID,
            AggregateType,
            AggregateID,
            EventType + '_REVERSED',
            EventVersion,
            JSON_MODIFY(EventData, '$.reversalReason', @Reason),
            JSON_MODIFY(ISNULL(EventMetadata, '{}'), '$.originalEventID', EventID),
            1, -- IsReversal
            EventID, -- ReversedByEventID
            @ReversalCorrelationID
        FROM dbo.DomainEvent
        WHERE EventID = @OriginalEventID;

        FETCH NEXT FROM @EventCursor INTO @OriginalEventID;
    END;

    CLOSE @EventCursor;
    DEALLOCATE @EventCursor;

    COMMIT TRANSACTION;

    RETURN 0;
END;
");

            migrationBuilder.Sql(@"
CREATE PROCEDURE dbo.usp_ReplayEvents
    @AggregateType          VARCHAR(50) = NULL,
    @AggregateID            VARCHAR(100) = NULL,
    @FromSequence           BIGINT = 0,
    @ToSequence             BIGINT = NULL,
    @BatchSize              INT = 1000
AS
BEGIN
    SET NOCOUNT ON;

    -- Return events for replay
    -- Application code will process these to rebuild projections
    SELECT TOP (@BatchSize)
        e.EventID,
        e.EventSequence,
        e.EventTimestamp,
        e.AggregateType,
        e.AggregateID,
        e.EventType,
        e.EventVersion,
        e.EventData,
        e.EventMetadata,
        e.IsReversal,
        e.CorrelationID
    FROM dbo.DomainEvent e
    WHERE (@AggregateType IS NULL OR e.AggregateType = @AggregateType)
      AND (@AggregateID IS NULL OR e.AggregateID = @AggregateID)
      AND e.EventSequence >= @FromSequence
      AND (@ToSequence IS NULL OR e.EventSequence <= @ToSequence)
      AND e.IsReversal = 0 -- Don't replay reversals
    ORDER BY e.EventSequence ASC;
END;
");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // =============================================
            // Drop Stored Procedures
            // =============================================
            
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.usp_ReplayEvents");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.usp_ReverseBatch");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.usp_UpdateEnrollmentProjection");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.usp_UpdateMemberProjection");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.usp_CreateSnapshot");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.usp_GetLatestSnapshot");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.usp_GetEventStream");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.usp_AppendEvent");

            // =============================================
            // Drop Views
            // =============================================
            
            migrationBuilder.Sql("DROP VIEW IF EXISTS dbo.vw_EventTypeStatistics");
            migrationBuilder.Sql("DROP VIEW IF EXISTS dbo.vw_ProjectionLag");
            migrationBuilder.Sql("DROP VIEW IF EXISTS dbo.vw_MemberEventHistory");
            migrationBuilder.Sql("DROP VIEW IF EXISTS dbo.vw_BatchProcessingSummary");
            migrationBuilder.Sql("DROP VIEW IF EXISTS dbo.vw_ActiveEnrollments");
            migrationBuilder.Sql("DROP VIEW IF EXISTS dbo.vw_EventStream");

            migrationBuilder.DropTable(
                name: "DomainEvent",
                schema: "dbo");

            migrationBuilder.DropTable(
                name: "Enrollment",
                schema: "dbo");

            migrationBuilder.DropTable(
                name: "EventSnapshot",
                schema: "dbo");

            migrationBuilder.DropTable(
                name: "TransactionHeader",
                schema: "dbo");

            migrationBuilder.DropTable(
                name: "Member",
                schema: "dbo");

            migrationBuilder.DropTable(
                name: "TransactionBatch",
                schema: "dbo");

            migrationBuilder.DropSequence(
                name: "EventSequence",
                schema: "dbo");
        }
    }
}
