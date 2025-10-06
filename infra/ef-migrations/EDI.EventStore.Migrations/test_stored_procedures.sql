-- =============================================
-- Test Stored Procedures
-- =============================================

SET QUOTED_IDENTIFIER ON;
GO

PRINT '=== Testing usp_AppendEvent ===';
GO

DECLARE @EventID BIGINT;
DECLARE @EventSequence BIGINT;
DECLARE @CorrelationID UNIQUEIDENTIFIER = NEWID();

EXEC dbo.usp_AppendEvent 
    @TransactionBatchID = 1,
    @AggregateType = 'Member',
    @AggregateID = 'SUB001',
    @EventType = 'MemberCreated',
    @EventData = '{"subscriberId": "SUB001", "firstName": "John", "lastName": "Doe"}',
    @CorrelationID = @CorrelationID,
    @EventID = @EventID OUTPUT,
    @EventSequence = @EventSequence OUTPUT;

SELECT @EventID AS EventID, @EventSequence AS EventSequence;
GO

PRINT '=== Testing usp_GetEventStream ===';
GO

EXEC dbo.usp_GetEventStream 
    @AggregateType = 'Member',
    @AggregateID = 'SUB001';
GO

PRINT '=== Testing usp_UpdateMemberProjection ===';
GO

EXEC dbo.usp_UpdateMemberProjection
    @SubscriberID = 'SUB001',
    @FirstName = 'John',
    @LastName = 'Doe',
    @DateOfBirth = '1980-01-01',
    @LastEventSequence = 1,
    @LastEventTimestamp = GETUTCDATE();
GO

PRINT '=== Testing usp_CreateSnapshot ===';
GO

EXEC dbo.usp_CreateSnapshot
    @AggregateType = 'Member',
    @AggregateID = 'SUB001',
    @SnapshotData = '{"subscriberId": "SUB001", "firstName": "John", "lastName": "Doe", "version": 1}',
    @EventSequence = 1;
GO

PRINT '=== Testing usp_GetLatestSnapshot ===';
GO

EXEC dbo.usp_GetLatestSnapshot
    @AggregateType = 'Member',
    @AggregateID = 'SUB001';
GO

PRINT '=== Verifying Data ===';
GO

SELECT 'DomainEvent' AS TableName, COUNT(*) AS RecordCount FROM dbo.DomainEvent
UNION ALL
SELECT 'Member', COUNT(*) FROM dbo.Member
UNION ALL
SELECT 'EventSnapshot', COUNT(*) FROM dbo.EventSnapshot
UNION ALL
SELECT 'TransactionBatch', COUNT(*) FROM dbo.TransactionBatch;
GO

PRINT '=== Testing Views ===';
GO

SELECT 'vw_EventStream' AS ViewName, COUNT(*) AS RecordCount FROM dbo.vw_EventStream;
SELECT 'vw_EventTypeStatistics' AS ViewName, COUNT(*) AS RecordCount FROM dbo.vw_EventTypeStatistics;
SELECT 'vw_ActiveEnrollments' AS ViewName, COUNT(*) AS RecordCount FROM dbo.vw_ActiveEnrollments;
GO

PRINT '=== All Tests Complete ===';
GO
