/*
    Control number store baseline schema.
    Run once per environment after the Azure SQL database is provisioned.
*/

SET XACT_ABORT ON;
GO

BEGIN TRAN;

IF OBJECT_ID('dbo.ControlNumberCounters', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ControlNumberCounters
    (
        CounterId           INT IDENTITY(1,1)            NOT NULL PRIMARY KEY,
        PartnerCode         NVARCHAR(15)                 NOT NULL,
        TransactionType     NVARCHAR(10)                 NOT NULL,
        CounterType         NVARCHAR(20)                 NOT NULL,
        CurrentValue        BIGINT                       NOT NULL CONSTRAINT DF_ControlNumberCounters_CurrentValue DEFAULT (1),
        MaxValue            BIGINT                       NOT NULL CONSTRAINT DF_ControlNumberCounters_MaxValue DEFAULT (999999999),
        LastIncrementUtc    DATETIME2(3)                 NOT NULL CONSTRAINT DF_ControlNumberCounters_LastIncrementUtc DEFAULT (SYSUTCDATETIME()),
        LastFileGenerated   NVARCHAR(255)                NULL,
        CreatedUtc          DATETIME2(3)                 NOT NULL CONSTRAINT DF_ControlNumberCounters_CreatedUtc DEFAULT (SYSUTCDATETIME()),
        ModifiedUtc         DATETIME2(3)                 NOT NULL CONSTRAINT DF_ControlNumberCounters_ModifiedUtc DEFAULT (SYSUTCDATETIME()),
        RowVersion          ROWVERSION                   NOT NULL
    );

    CREATE UNIQUE INDEX UQ_ControlNumberCounters_Key
        ON dbo.ControlNumberCounters (PartnerCode, TransactionType, CounterType);

    CREATE INDEX IX_ControlNumberCounters_PartnerType
        ON dbo.ControlNumberCounters (PartnerCode, TransactionType)
        INCLUDE (CurrentValue, LastIncrementUtc);
END;

IF OBJECT_ID('dbo.ControlNumberAudit', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ControlNumberAudit
    (
        AuditId             BIGINT IDENTITY(1,1)         NOT NULL PRIMARY KEY,
        CounterId           INT                          NOT NULL CONSTRAINT FK_ControlNumberAudit_CounterId REFERENCES dbo.ControlNumberCounters(CounterId),
        ControlNumberIssued BIGINT                       NOT NULL,
        OutboundFileId      UNIQUEIDENTIFIER             NOT NULL,
        IssuedUtc           DATETIME2(3)                 NOT NULL CONSTRAINT DF_ControlNumberAudit_IssuedUtc DEFAULT (SYSUTCDATETIME()),
        RetryCount          INT                          NOT NULL CONSTRAINT DF_ControlNumberAudit_RetryCount DEFAULT (0),
        Status              NVARCHAR(20)                 NOT NULL CONSTRAINT DF_ControlNumberAudit_Status DEFAULT ('ISSUED'),
        Notes               NVARCHAR(500)                NULL
    );

    CREATE INDEX IX_ControlNumberAudit_CounterId
        ON dbo.ControlNumberAudit (CounterId, IssuedUtc);

    CREATE INDEX IX_ControlNumberAudit_OutboundFileId
        ON dbo.ControlNumberAudit (OutboundFileId);
END;

IF OBJECT_ID('dbo.ControlNumberGaps', 'V') IS NOT NULL
BEGIN
    DROP VIEW dbo.ControlNumberGaps;
END;

EXEC ('
CREATE VIEW dbo.ControlNumberGaps
AS
    WITH NumberedAudit AS (
        SELECT
            a.CounterId,
            c.PartnerCode,
            c.TransactionType,
            c.CounterType,
            a.ControlNumberIssued,
            LAG(a.ControlNumberIssued) OVER (PARTITION BY a.CounterId ORDER BY a.ControlNumberIssued) AS PreviousNumber
        FROM dbo.ControlNumberAudit a
        INNER JOIN dbo.ControlNumberCounters c ON a.CounterId = c.CounterId
        WHERE a.Status IN (''ISSUED'', ''PERSISTED'')
    )
    SELECT
        PartnerCode,
        TransactionType,
        CounterType,
        PreviousNumber AS GapStart,
        ControlNumberIssued AS GapEnd,
        (ControlNumberIssued - PreviousNumber - 1) AS GapSize
    FROM NumberedAudit
    WHERE PreviousNumber IS NOT NULL
      AND ControlNumberIssued - PreviousNumber > 1;
');

COMMIT;
GO
