/*
    Enrollment Event Store - Views and Queries
    Run after tables and procedures are created
*/

SET XACT_ABORT ON;
GO

-- =============================================
-- View: Active Enrollments
-- =============================================
IF OBJECT_ID('dbo.vw_ActiveEnrollments', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ActiveEnrollments;
GO

CREATE VIEW dbo.vw_ActiveEnrollments
AS
    SELECT 
        m.MemberID,
        m.SubscriberID,
        m.FirstName,
        m.MiddleName,
        m.LastName,
        m.DateOfBirth,
        m.Gender,
        m.RelationshipCode,
        e.EnrollmentID,
        e.EffectiveDate,
        e.TerminationDate,
        e.MaintenanceTypeCode,
        e.BenefitStatusCode,
        e.GroupNumber,
        e.PlanIdentifier,
        e.LastEventSequence AS EnrollmentLastEventSequence,
        e.LastEventTimestamp AS EnrollmentLastEventTimestamp,
        m.LastEventSequence AS MemberLastEventSequence,
        m.LastEventTimestamp AS MemberLastEventTimestamp
    FROM dbo.Member m
    INNER JOIN dbo.Enrollment e ON m.MemberID = e.MemberID
    WHERE e.IsActive = 1
      AND m.IsActive = 1;
GO

-- =============================================
-- View: Event Stream (with batch context)
-- =============================================
IF OBJECT_ID('dbo.vw_EventStream', 'V') IS NOT NULL
    DROP VIEW dbo.vw_EventStream;
GO

CREATE VIEW dbo.vw_EventStream
AS
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
        e.CorrelationID,
        e.CausationID,
        b.BatchGUID,
        b.PartnerCode,
        b.Direction,
        b.TransactionType,
        b.FileName,
        b.InterchangeControlNumber,
        th.TransactionSetControlNumber,
        th.PurposeCode
    FROM dbo.DomainEvent e
    INNER JOIN dbo.TransactionBatch b ON e.TransactionBatchID = b.TransactionBatchID
    LEFT JOIN dbo.TransactionHeader th ON e.TransactionHeaderID = th.TransactionHeaderID;
GO

-- =============================================
-- View: Batch Processing Summary
-- =============================================
IF OBJECT_ID('dbo.vw_BatchProcessingSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_BatchProcessingSummary;
GO

CREATE VIEW dbo.vw_BatchProcessingSummary
AS
    SELECT 
        b.TransactionBatchID,
        b.BatchGUID,
        b.PartnerCode,
        b.Direction,
        b.TransactionType,
        b.FileName,
        b.FileReceivedDate,
        b.ProcessingStatus,
        b.ProcessingStartedUtc,
        b.ProcessingCompletedUtc,
        DATEDIFF(SECOND, b.ProcessingStartedUtc, COALESCE(b.ProcessingCompletedUtc, SYSUTCDATETIME())) AS ProcessingDurationSeconds,
        b.EventCount,
        COUNT(DISTINCT th.TransactionHeaderID) AS TransactionCount,
        SUM(th.MemberCount) AS TotalMemberCount,
        b.InterchangeControlNumber,
        b.FunctionalGroupControlNumber,
        b.ErrorMessage
    FROM dbo.TransactionBatch b
    LEFT JOIN dbo.TransactionHeader th ON b.TransactionBatchID = th.TransactionBatchID
    GROUP BY 
        b.TransactionBatchID,
        b.BatchGUID,
        b.PartnerCode,
        b.Direction,
        b.TransactionType,
        b.FileName,
        b.FileReceivedDate,
        b.ProcessingStatus,
        b.ProcessingStartedUtc,
        b.ProcessingCompletedUtc,
        b.EventCount,
        b.InterchangeControlNumber,
        b.FunctionalGroupControlNumber,
        b.ErrorMessage;
GO

-- =============================================
-- View: Member Event History
-- =============================================
IF OBJECT_ID('dbo.vw_MemberEventHistory', 'V') IS NOT NULL
    DROP VIEW dbo.vw_MemberEventHistory;
GO

CREATE VIEW dbo.vw_MemberEventHistory
AS
    SELECT 
        m.MemberID,
        m.SubscriberID,
        m.FirstName,
        m.LastName,
        e.EventID,
        e.EventSequence,
        e.EventTimestamp,
        e.EventType,
        e.EventVersion,
        e.EventData,
        e.IsReversal,
        b.PartnerCode,
        b.FileName,
        b.FileReceivedDate,
        e.CorrelationID
    FROM dbo.Member m
    INNER JOIN dbo.DomainEvent e ON m.SubscriberID = e.AggregateID
    INNER JOIN dbo.TransactionBatch b ON e.TransactionBatchID = b.TransactionBatchID
    WHERE e.AggregateType = 'Member';
GO

-- =============================================
-- View: Event Type Statistics
-- =============================================
IF OBJECT_ID('dbo.vw_EventTypeStatistics', 'V') IS NOT NULL
    DROP VIEW dbo.vw_EventTypeStatistics;
GO

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
GO

-- =============================================
-- View: Projection Lag (Event vs Projection)
-- =============================================
IF OBJECT_ID('dbo.vw_ProjectionLag', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ProjectionLag;
GO

CREATE VIEW dbo.vw_ProjectionLag
AS
    SELECT 
        'Member' AS ProjectionType,
        m.SubscriberID AS AggregateID,
        m.LastEventSequence AS ProjectionSequence,
        MAX(e.EventSequence) AS LatestEventSequence,
        MAX(e.EventSequence) - m.LastEventSequence AS SequenceLag,
        DATEDIFF(SECOND, m.LastEventTimestamp, MAX(e.EventTimestamp)) AS TimeLagSeconds
    FROM dbo.Member m
    LEFT JOIN dbo.DomainEvent e ON m.SubscriberID = e.AggregateID AND e.AggregateType = 'Member'
    GROUP BY m.SubscriberID, m.LastEventSequence, m.LastEventTimestamp
    HAVING MAX(e.EventSequence) > m.LastEventSequence

    UNION ALL

    SELECT 
        'Enrollment' AS ProjectionType,
        m.SubscriberID AS AggregateID,
        e.LastEventSequence AS ProjectionSequence,
        MAX(de.EventSequence) AS LatestEventSequence,
        MAX(de.EventSequence) - e.LastEventSequence AS SequenceLag,
        DATEDIFF(SECOND, e.LastEventTimestamp, MAX(de.EventTimestamp)) AS TimeLagSeconds
    FROM dbo.Enrollment e
    INNER JOIN dbo.Member m ON e.MemberID = m.MemberID
    LEFT JOIN dbo.DomainEvent de ON m.SubscriberID = de.AggregateID AND de.AggregateType = 'Enrollment'
    GROUP BY m.SubscriberID, e.LastEventSequence, e.LastEventTimestamp
    HAVING MAX(de.EventSequence) > e.LastEventSequence;
GO

PRINT 'Enrollment Event Store views created successfully.';
PRINT '';
PRINT 'Available Views:';
PRINT '  - vw_ActiveEnrollments: Current active member enrollments';
PRINT '  - vw_EventStream: Complete event stream with batch context';
PRINT '  - vw_BatchProcessingSummary: Batch processing metrics';
PRINT '  - vw_MemberEventHistory: Member-specific event history';
PRINT '  - vw_EventTypeStatistics: Event type distribution and counts';
PRINT '  - vw_ProjectionLag: Identify out-of-sync projections';
GO
