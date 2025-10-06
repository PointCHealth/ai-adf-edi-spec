/*
    Control Number Management - Stored Procedures
    Run after 001_create_control_number_tables.sql
*/

SET XACT_ABORT ON;
GO

-- =============================================
-- Get Next Control Number (with optimistic concurrency)
-- =============================================
IF OBJECT_ID('dbo.usp_GetNextControlNumber', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetNextControlNumber;
GO

CREATE PROCEDURE dbo.usp_GetNextControlNumber
    @PartnerCode        NVARCHAR(15),
    @TransactionType    NVARCHAR(10),
    @CounterType        NVARCHAR(20),
    @OutboundFileId     UNIQUEIDENTIFIER,
    @NextControlNumber  BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MaxRetries INT = 5;
    DECLARE @RetryCount INT = 0;
    DECLARE @CurrentRowVersion BINARY(8);
    DECLARE @CurrentValue BIGINT;
    DECLARE @MaxValue BIGINT;
    DECLARE @CounterId INT;

    WHILE @RetryCount < @MaxRetries
    BEGIN
        BEGIN TRY
            -- Read current value and row version
            SELECT 
                @CounterId = CounterId,
                @CurrentValue = CurrentValue,
                @MaxValue = MaxValue,
                @CurrentRowVersion = RowVersion
            FROM dbo.ControlNumberCounters WITH (UPDLOCK, READPAST)
            WHERE PartnerCode = @PartnerCode 
              AND TransactionType = @TransactionType 
              AND CounterType = @CounterType;

            -- Initialize counter if not exists
            IF @CounterId IS NULL
            BEGIN
                INSERT INTO dbo.ControlNumberCounters (PartnerCode, TransactionType, CounterType)
                VALUES (@PartnerCode, @TransactionType, @CounterType);

                SELECT 
                    @CounterId = CounterId,
                    @CurrentValue = CurrentValue,
                    @MaxValue = MaxValue,
                    @CurrentRowVersion = RowVersion
                FROM dbo.ControlNumberCounters
                WHERE PartnerCode = @PartnerCode 
                  AND TransactionType = @TransactionType 
                  AND CounterType = @CounterType;
            END;

            -- Calculate next value
            SET @NextControlNumber = @CurrentValue + 1;

            -- Check for rollover
            IF @NextControlNumber > @MaxValue
            BEGIN
                THROW 50001, 'Control number max value exceeded. Rollover required.', 1;
            END;

            -- Attempt update with concurrency check
            UPDATE dbo.ControlNumberCounters
            SET 
                CurrentValue = @NextControlNumber,
                LastIncrementUtc = SYSUTCDATETIME(),
                ModifiedUtc = SYSUTCDATETIME()
            WHERE CounterId = @CounterId
              AND RowVersion = @CurrentRowVersion; -- Optimistic concurrency check

            -- Check if update succeeded
            IF @@ROWCOUNT = 1
            BEGIN
                -- Success - insert audit record
                INSERT INTO dbo.ControlNumberAudit 
                    (CounterId, ControlNumberIssued, OutboundFileId, RetryCount, Status)
                VALUES 
                    (@CounterId, @NextControlNumber, @OutboundFileId, @RetryCount, 'ISSUED');

                -- Return success
                RETURN 0;
            END
            ELSE
            BEGIN
                -- Concurrency collision - retry
                SET @RetryCount = @RetryCount + 1;
                WAITFOR DELAY '00:00:00.050'; -- 50ms base delay
            END;

        END TRY
        BEGIN CATCH
            -- Log error and retry
            SET @RetryCount = @RetryCount + 1;
            
            IF @RetryCount >= @MaxRetries
            BEGIN
                THROW;
            END;
            
            WAITFOR DELAY '00:00:00.100'; -- 100ms on error
        END CATCH;
    END;

    -- Max retries exceeded
    THROW 50002, 'Control number acquisition failed after maximum retries', 1;
END;
GO

-- =============================================
-- Mark Control Number as Persisted
-- =============================================
IF OBJECT_ID('dbo.usp_MarkControlNumberPersisted', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_MarkControlNumberPersisted;
GO

CREATE PROCEDURE dbo.usp_MarkControlNumberPersisted
    @OutboundFileId     UNIQUEIDENTIFIER,
    @FileName           NVARCHAR(255),
    @Notes              NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Update audit record
    UPDATE dbo.ControlNumberAudit
    SET 
        Status = 'PERSISTED',
        Notes = COALESCE(@Notes, Notes)
    WHERE OutboundFileId = @OutboundFileId
      AND Status = 'ISSUED';

    -- Update counter with file name
    UPDATE c
    SET LastFileGenerated = @FileName
    FROM dbo.ControlNumberCounters c
    INNER JOIN dbo.ControlNumberAudit a ON c.CounterId = a.CounterId
    WHERE a.OutboundFileId = @OutboundFileId;

    RETURN @@ROWCOUNT;
END;
GO

-- =============================================
-- Detect Control Number Gaps
-- =============================================
IF OBJECT_ID('dbo.usp_DetectControlNumberGaps', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_DetectControlNumberGaps;
GO

CREATE PROCEDURE dbo.usp_DetectControlNumberGaps
    @PartnerCode        NVARCHAR(15) = NULL,
    @TransactionType    NVARCHAR(10) = NULL,
    @DaysToCheck        INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartDate DATETIME2 = DATEADD(DAY, -@DaysToCheck, SYSUTCDATETIME());

    SELECT 
        PartnerCode,
        TransactionType,
        CounterType,
        GapStart,
        GapEnd,
        GapSize,
        CASE 
            WHEN GapSize = 1 THEN 'MINOR'
            WHEN GapSize <= 5 THEN 'MODERATE'
            ELSE 'CRITICAL'
        END AS Severity
    FROM dbo.ControlNumberGaps
    WHERE (@PartnerCode IS NULL OR PartnerCode = @PartnerCode)
      AND (@TransactionType IS NULL OR TransactionType = @TransactionType)
    ORDER BY GapSize DESC, PartnerCode, TransactionType, CounterType;
END;
GO

-- =============================================
-- Get Control Number Status
-- =============================================
IF OBJECT_ID('dbo.usp_GetControlNumberStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetControlNumberStatus;
GO

CREATE PROCEDURE dbo.usp_GetControlNumberStatus
    @PartnerCode        NVARCHAR(15) = NULL,
    @TransactionType    NVARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        c.PartnerCode,
        c.TransactionType,
        c.CounterType,
        c.CurrentValue,
        c.MaxValue,
        CAST(c.CurrentValue AS FLOAT) / c.MaxValue * 100 AS PercentUsed,
        c.LastIncrementUtc,
        c.LastFileGenerated,
        COUNT(a.AuditId) AS TotalIssued,
        SUM(CASE WHEN a.Status = 'ISSUED' THEN 1 ELSE 0 END) AS PendingCount,
        SUM(CASE WHEN a.Status = 'PERSISTED' THEN 1 ELSE 0 END) AS PersistedCount,
        SUM(a.RetryCount) AS TotalRetries,
        MAX(a.IssuedUtc) AS LastIssuedUtc
    FROM dbo.ControlNumberCounters c
    LEFT JOIN dbo.ControlNumberAudit a ON c.CounterId = a.CounterId
    WHERE (@PartnerCode IS NULL OR c.PartnerCode = @PartnerCode)
      AND (@TransactionType IS NULL OR c.TransactionType = @TransactionType)
    GROUP BY 
        c.PartnerCode,
        c.TransactionType,
        c.CounterType,
        c.CurrentValue,
        c.MaxValue,
        c.LastIncrementUtc,
        c.LastFileGenerated
    ORDER BY c.PartnerCode, c.TransactionType, c.CounterType;
END;
GO

-- =============================================
-- Reset Control Number (Emergency Use Only)
-- =============================================
IF OBJECT_ID('dbo.usp_ResetControlNumber', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_ResetControlNumber;
GO

CREATE PROCEDURE dbo.usp_ResetControlNumber
    @PartnerCode        NVARCHAR(15),
    @TransactionType    NVARCHAR(10),
    @CounterType        NVARCHAR(20),
    @NewValue           BIGINT = 1,
    @Reason             NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CounterId INT;

    BEGIN TRANSACTION;

    -- Get counter ID
    SELECT @CounterId = CounterId
    FROM dbo.ControlNumberCounters
    WHERE PartnerCode = @PartnerCode 
      AND TransactionType = @TransactionType 
      AND CounterType = @CounterType;

    IF @CounterId IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50003, 'Control number counter not found', 1;
    END;

    -- Log reset in audit table
    INSERT INTO dbo.ControlNumberAudit 
        (CounterId, ControlNumberIssued, OutboundFileId, RetryCount, Status, Notes)
    VALUES 
        (@CounterId, @NewValue, NEWID(), 0, 'RESET', @Reason);

    -- Reset counter
    UPDATE dbo.ControlNumberCounters
    SET 
        CurrentValue = @NewValue,
        LastIncrementUtc = SYSUTCDATETIME(),
        ModifiedUtc = SYSUTCDATETIME()
    WHERE CounterId = @CounterId;

    COMMIT TRANSACTION;

    RETURN 0;
END;
GO

-- =============================================
-- Grant permissions (adjust for your security model)
-- =============================================
-- GRANT EXECUTE ON dbo.usp_GetNextControlNumber TO [EDI_Function_App_Identity];
-- GRANT EXECUTE ON dbo.usp_MarkControlNumberPersisted TO [EDI_Function_App_Identity];
-- GRANT EXECUTE ON dbo.usp_DetectControlNumberGaps TO [EDI_Monitor_Identity];
-- GRANT EXECUTE ON dbo.usp_GetControlNumberStatus TO [EDI_Monitor_Identity];
-- GRANT EXECUTE ON dbo.usp_ResetControlNumber TO [EDI_Admin_Identity];

PRINT 'Control Number stored procedures created successfully.';
GO
