/*
    Enrollment Event Store - Stored Procedures
    Run after 001_create_event_store_tables.sql
*/

SET XACT_ABORT ON;
GO

-- =============================================
-- Append Event to Event Store
-- =============================================
IF OBJECT_ID('dbo.usp_AppendEvent', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_AppendEvent;
GO

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
GO

-- =============================================
-- Get Event Stream for Aggregate
-- =============================================
IF OBJECT_ID('dbo.usp_GetEventStream', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetEventStream;
GO

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
GO

-- =============================================
-- Replay Events to Rebuild Projections
-- =============================================
IF OBJECT_ID('dbo.usp_ReplayEvents', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_ReplayEvents;
GO

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
GO

-- =============================================
-- Update Member Projection
-- =============================================
IF OBJECT_ID('dbo.usp_UpdateMemberProjection', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_UpdateMemberProjection;
GO

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
GO

-- =============================================
-- Update Enrollment Projection
-- =============================================
IF OBJECT_ID('dbo.usp_UpdateEnrollmentProjection', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_UpdateEnrollmentProjection;
GO

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
GO

-- =============================================
-- Create Snapshot
-- =============================================
IF OBJECT_ID('dbo.usp_CreateSnapshot', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CreateSnapshot;
GO

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
GO

-- =============================================
-- Get Latest Snapshot
-- =============================================
IF OBJECT_ID('dbo.usp_GetLatestSnapshot', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetLatestSnapshot;
GO

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
GO

-- =============================================
-- Reverse Transaction Batch (Error correction)
-- =============================================
IF OBJECT_ID('dbo.usp_ReverseBatch', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_ReverseBatch;
GO

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
GO

-- =============================================
-- Grant permissions (adjust for your security model)
-- =============================================
-- GRANT EXECUTE ON dbo.usp_AppendEvent TO [EDI_Function_App_Identity];
-- GRANT EXECUTE ON dbo.usp_GetEventStream TO [EDI_Function_App_Identity];
-- GRANT EXECUTE ON dbo.usp_UpdateMemberProjection TO [EDI_Function_App_Identity];
-- GRANT EXECUTE ON dbo.usp_UpdateEnrollmentProjection TO [EDI_Function_App_Identity];
-- GRANT EXECUTE ON dbo.usp_CreateSnapshot TO [EDI_Function_App_Identity];
-- GRANT EXECUTE ON dbo.usp_GetLatestSnapshot TO [EDI_Function_App_Identity];
-- GRANT EXECUTE ON dbo.usp_ReplayEvents TO [EDI_Admin_Identity];
-- GRANT EXECUTE ON dbo.usp_ReverseBatch TO [EDI_Admin_Identity];

PRINT 'Enrollment Event Store stored procedures created successfully.';
GO
