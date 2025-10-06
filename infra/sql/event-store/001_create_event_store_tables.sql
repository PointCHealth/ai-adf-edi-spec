/*
    Enrollment Event Store - Baseline Schema
    Event sourcing database for 834 enrollment transactions
    Run once per environment after Azure SQL database is provisioned
*/

SET XACT_ABORT ON;
GO

BEGIN TRAN;

PRINT 'Creating Enrollment Event Store schema...';

-- =============================================
-- Event Sequence (Gap-free monotonic ordering)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.sequences WHERE name = 'EventSequence')
BEGIN
    CREATE SEQUENCE dbo.EventSequence 
    AS BIGINT 
    START WITH 1 
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    NO CYCLE
    CACHE 100; -- Cache for performance
    
    PRINT '  ✓ Created EventSequence';
END;

-- =============================================
-- TransactionBatch (Source files/messages)
-- =============================================
IF OBJECT_ID('dbo.TransactionBatch', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TransactionBatch
    (
        TransactionBatchID      BIGINT IDENTITY(1,1)        NOT NULL PRIMARY KEY,
        BatchGUID               UNIQUEIDENTIFIER            NOT NULL DEFAULT NEWID() UNIQUE,
        PartnerCode             NVARCHAR(15)                NOT NULL,
        Direction               NVARCHAR(10)                NOT NULL, -- 'INBOUND', 'OUTBOUND'
        TransactionType         NVARCHAR(10)                NOT NULL, -- '834', '270', etc.
        
        -- Source identification
        FileName                NVARCHAR(500)               NULL,
        FileHash                VARCHAR(64)                 NULL, -- SHA256 for idempotency
        FileReceivedDate        DATETIME2(3)                NOT NULL,
        BlobFullUri             NVARCHAR(1000)              NULL,
        
        -- EDI envelope identifiers
        InterchangeControlNumber NVARCHAR(15)               NULL,
        FunctionalGroupControlNumber NVARCHAR(15)           NULL,
        
        -- Processing metadata
        ProcessingStatus        NVARCHAR(20)                NOT NULL DEFAULT 'RECEIVED', -- RECEIVED, PROCESSING, COMPLETED, FAILED
        ProcessingStartedUtc    DATETIME2(3)                NULL,
        ProcessingCompletedUtc  DATETIME2(3)                NULL,
        ErrorMessage            NVARCHAR(MAX)               NULL,
        
        -- Event correlation
        FirstEventSequence      BIGINT                      NULL,
        LastEventSequence       BIGINT                      NULL,
        EventCount              INT                         NOT NULL DEFAULT 0,
        
        -- Audit fields
        CreatedUtc              DATETIME2(3)                NOT NULL DEFAULT SYSUTCDATETIME(),
        ModifiedUtc             DATETIME2(3)                NOT NULL DEFAULT SYSUTCDATETIME(),
        RowVersion              ROWVERSION                  NOT NULL,
        
        CONSTRAINT CHK_TransactionBatch_Direction CHECK (Direction IN ('INBOUND', 'OUTBOUND')),
        CONSTRAINT CHK_TransactionBatch_Status CHECK (ProcessingStatus IN ('RECEIVED', 'PROCESSING', 'COMPLETED', 'FAILED', 'REVERSED'))
    );

    CREATE UNIQUE INDEX UQ_TransactionBatch_FileHash 
        ON dbo.TransactionBatch (FileHash) 
        WHERE FileHash IS NOT NULL;
    
    CREATE INDEX IX_TransactionBatch_Partner 
        ON dbo.TransactionBatch (PartnerCode, TransactionType, FileReceivedDate DESC);
    
    CREATE INDEX IX_TransactionBatch_Status 
        ON dbo.TransactionBatch (ProcessingStatus, FileReceivedDate DESC);
    
    CREATE INDEX IX_TransactionBatch_ControlNumbers 
        ON dbo.TransactionBatch (InterchangeControlNumber, FunctionalGroupControlNumber);
    
    PRINT '  ✓ Created TransactionBatch table';
END;

-- =============================================
-- TransactionHeader (834 transaction sets within batch)
-- =============================================
IF OBJECT_ID('dbo.TransactionHeader', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TransactionHeader
    (
        TransactionHeaderID     BIGINT IDENTITY(1,1)        NOT NULL PRIMARY KEY,
        TransactionGUID         UNIQUEIDENTIFIER            NOT NULL DEFAULT NEWID() UNIQUE,
        TransactionBatchID      BIGINT                      NOT NULL,
        
        -- EDI identifiers
        TransactionSetControlNumber NVARCHAR(15)            NOT NULL,
        PurposeCode             NVARCHAR(10)                NULL, -- '00' Original, '05' Replace, etc.
        ReferenceIdentification NVARCHAR(50)                NULL,
        TransactionDate         DATE                        NULL,
        
        -- Processing metadata
        SegmentCount            INT                         NOT NULL DEFAULT 0,
        MemberCount             INT                         NOT NULL DEFAULT 0,
        ProcessingStatus        NVARCHAR(20)                NOT NULL DEFAULT 'RECEIVED',
        
        -- Event correlation
        FirstEventSequence      BIGINT                      NULL,
        LastEventSequence       BIGINT                      NULL,
        
        -- Audit fields
        CreatedUtc              DATETIME2(3)                NOT NULL DEFAULT SYSUTCDATETIME(),
        ModifiedUtc             DATETIME2(3)                NOT NULL DEFAULT SYSUTCDATETIME(),
        
        CONSTRAINT FK_TransactionHeader_Batch FOREIGN KEY (TransactionBatchID) 
            REFERENCES dbo.TransactionBatch(TransactionBatchID)
    );

    CREATE INDEX IX_TransactionHeader_Batch 
        ON dbo.TransactionHeader (TransactionBatchID);
    
    CREATE INDEX IX_TransactionHeader_ControlNumber 
        ON dbo.TransactionHeader (TransactionSetControlNumber);
    
    PRINT '  ✓ Created TransactionHeader table';
END;

-- =============================================
-- DomainEvent (Event Store - Append Only)
-- =============================================
IF OBJECT_ID('dbo.DomainEvent', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DomainEvent
    (
        EventID                 BIGINT IDENTITY(1,1)        NOT NULL PRIMARY KEY,
        EventGUID               UNIQUEIDENTIFIER            NOT NULL DEFAULT NEWID() UNIQUE,
        
        -- Source correlation
        TransactionBatchID      BIGINT                      NOT NULL,
        TransactionHeaderID     BIGINT                      NULL,
        
        -- Event classification
        AggregateType           VARCHAR(50)                 NOT NULL, -- 'Member', 'Enrollment', 'Coverage'
        AggregateID             VARCHAR(100)                NOT NULL, -- Business key (SubscriberID, MemberID)
        EventType               VARCHAR(100)                NOT NULL, -- 'MemberAdded', 'EnrollmentTerminated', etc.
        EventVersion            INT                         NOT NULL DEFAULT 1,
        
        -- Event payload
        EventData               NVARCHAR(MAX)               NOT NULL, -- JSON
        EventMetadata           NVARCHAR(MAX)               NULL,     -- JSON
        
        -- Temporal ordering
        EventTimestamp          DATETIME2(3)                NOT NULL DEFAULT SYSUTCDATETIME(),
        EventSequence           BIGINT                      NOT NULL DEFAULT NEXT VALUE FOR dbo.EventSequence,
        
        -- Event characteristics
        IsReversal              BIT                         NOT NULL DEFAULT 0,
        ReversedByEventID       BIGINT                      NULL,
        
        -- Processing metadata
        CorrelationID           UNIQUEIDENTIFIER            NOT NULL,
        CausationID             UNIQUEIDENTIFIER            NULL,
        
        -- Audit
        CreatedUtc              DATETIME2(3)                NOT NULL DEFAULT SYSUTCDATETIME(),
        
        CONSTRAINT FK_DomainEvent_Batch FOREIGN KEY (TransactionBatchID) 
            REFERENCES dbo.TransactionBatch(TransactionBatchID),
        CONSTRAINT FK_DomainEvent_Header FOREIGN KEY (TransactionHeaderID) 
            REFERENCES dbo.TransactionHeader(TransactionHeaderID),
        CONSTRAINT FK_DomainEvent_ReversedBy FOREIGN KEY (ReversedByEventID) 
            REFERENCES dbo.DomainEvent(EventID)
    );

    -- Critical indexes for event sourcing patterns
    CREATE UNIQUE INDEX UQ_DomainEvent_Sequence 
        ON dbo.DomainEvent (EventSequence);
    
    CREATE INDEX IX_DomainEvent_Aggregate 
        ON dbo.DomainEvent (AggregateType, AggregateID, EventSequence);
    
    CREATE INDEX IX_DomainEvent_Type 
        ON dbo.DomainEvent (EventType, EventTimestamp);
    
    CREATE INDEX IX_DomainEvent_Batch 
        ON dbo.DomainEvent (TransactionBatchID, EventSequence);
    
    CREATE INDEX IX_DomainEvent_Correlation 
        ON dbo.DomainEvent (CorrelationID);
    
    CREATE INDEX IX_DomainEvent_Timestamp 
        ON dbo.DomainEvent (EventTimestamp, EventSequence);
    
    PRINT '  ✓ Created DomainEvent table (Event Store)';
END;

-- =============================================
-- Member (Current State Projection)
-- =============================================
IF OBJECT_ID('dbo.Member', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Member
    (
        MemberID                BIGINT IDENTITY(1,1)        NOT NULL PRIMARY KEY,
        
        -- Business identifiers
        SubscriberID            VARCHAR(50)                 NOT NULL UNIQUE,
        MemberSuffix            VARCHAR(10)                 NULL,
        SSN                     VARCHAR(11)                 NULL,
        
        -- Demographics
        FirstName               NVARCHAR(50)                NOT NULL,
        MiddleName              NVARCHAR(50)                NULL,
        LastName                NVARCHAR(50)                NOT NULL,
        DateOfBirth             DATE                        NOT NULL,
        Gender                  CHAR(1)                     NULL,
        
        -- Contact information
        AddressLine1            NVARCHAR(100)               NULL,
        AddressLine2            NVARCHAR(100)               NULL,
        City                    NVARCHAR(50)                NULL,
        State                   CHAR(2)                     NULL,
        ZipCode                 VARCHAR(10)                 NULL,
        PhoneNumber             VARCHAR(20)                 NULL,
        EmailAddress            NVARCHAR(100)               NULL,
        
        -- Enrollment status
        RelationshipCode        VARCHAR(2)                  NULL, -- '18' = Self, '01' = Spouse, etc.
        EmploymentStatusCode    VARCHAR(2)                  NULL,
        
        -- Projection metadata
        Version                 INT                         NOT NULL DEFAULT 1, -- Optimistic concurrency
        LastEventSequence       BIGINT                      NOT NULL,
        LastEventTimestamp      DATETIME2(3)                NOT NULL,
        IsActive                BIT                         NOT NULL DEFAULT 1,
        
        -- Audit fields
        CreatedUtc              DATETIME2(3)                NOT NULL DEFAULT SYSUTCDATETIME(),
        ModifiedUtc             DATETIME2(3)                NOT NULL DEFAULT SYSUTCDATETIME(),
        
        CONSTRAINT CHK_Member_Gender CHECK (Gender IN ('M', 'F', 'U'))
    );

    CREATE INDEX IX_Member_Name 
        ON dbo.Member (LastName, FirstName, DateOfBirth);
    
    CREATE INDEX IX_Member_SSN 
        ON dbo.Member (SSN) 
        WHERE SSN IS NOT NULL;
    
    CREATE INDEX IX_Member_LastEvent 
        ON dbo.Member (LastEventSequence);
    
    PRINT '  ✓ Created Member projection table';
END;

-- =============================================
-- Enrollment (Current State Projection)
-- =============================================
IF OBJECT_ID('dbo.Enrollment', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Enrollment
    (
        EnrollmentID            BIGINT IDENTITY(1,1)        NOT NULL PRIMARY KEY,
        MemberID                BIGINT                      NOT NULL,
        
        -- Enrollment details
        EffectiveDate           DATE                        NOT NULL,
        TerminationDate         DATE                        NULL,
        MaintenanceTypeCode     VARCHAR(3)                  NOT NULL, -- '001' Change, '021' Add, '024' Term, '025' Cancel
        MaintenanceReasonCode   VARCHAR(3)                  NULL,
        BenefitStatusCode       VARCHAR(2)                  NULL,
        
        -- Plan information
        GroupNumber             VARCHAR(50)                 NULL,
        PlanIdentifier          VARCHAR(50)                 NULL,
        
        -- Status
        IsActive                BIT                         NOT NULL DEFAULT 1,
        
        -- Projection metadata
        Version                 INT                         NOT NULL DEFAULT 1,
        LastEventSequence       BIGINT                      NOT NULL,
        LastEventTimestamp      DATETIME2(3)                NOT NULL,
        
        -- Audit fields
        CreatedUtc              DATETIME2(3)                NOT NULL DEFAULT SYSUTCDATETIME(),
        ModifiedUtc             DATETIME2(3)                NOT NULL DEFAULT SYSUTCDATETIME(),
        
        CONSTRAINT FK_Enrollment_Member FOREIGN KEY (MemberID) 
            REFERENCES dbo.Member(MemberID)
    );

    CREATE INDEX IX_Enrollment_Member 
        ON dbo.Enrollment (MemberID, IsActive);
    
    CREATE INDEX IX_Enrollment_Dates 
        ON dbo.Enrollment (EffectiveDate, TerminationDate);
    
    CREATE INDEX IX_Enrollment_Plan 
        ON dbo.Enrollment (GroupNumber, PlanIdentifier);
    
    PRINT '  ✓ Created Enrollment projection table';
END;

-- =============================================
-- EventSnapshot (Performance optimization)
-- =============================================
IF OBJECT_ID('dbo.EventSnapshot', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EventSnapshot
    (
        SnapshotID              BIGINT IDENTITY(1,1)        NOT NULL PRIMARY KEY,
        AggregateType           VARCHAR(50)                 NOT NULL,
        AggregateID             VARCHAR(100)                NOT NULL,
        
        -- Snapshot data
        SnapshotData            NVARCHAR(MAX)               NOT NULL, -- JSON
        SnapshotVersion         INT                         NOT NULL,
        
        -- Temporal tracking
        EventSequence           BIGINT                      NOT NULL, -- Last event in snapshot
        SnapshotTimestamp       DATETIME2(3)                NOT NULL DEFAULT SYSUTCDATETIME(),
        
        CONSTRAINT UQ_EventSnapshot_Aggregate UNIQUE (AggregateType, AggregateID, SnapshotVersion)
    );

    CREATE INDEX IX_EventSnapshot_Sequence 
        ON dbo.EventSnapshot (EventSequence);
    
    PRINT '  ✓ Created EventSnapshot table';
END;

COMMIT;

PRINT 'Enrollment Event Store schema created successfully.';
GO
