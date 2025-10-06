/*
    Enrollment Event Store - Seed Data
    Run after schema, procedures, and views are deployed
    Creates sample data for testing and development
*/

SET XACT_ABORT ON;
GO

PRINT 'Seeding Enrollment Event Store with sample data...';
PRINT '';

BEGIN TRAN;

-- =============================================
-- Seed Sample Transaction Batch
-- =============================================
DECLARE @BatchID BIGINT;
DECLARE @HeaderID BIGINT;
DECLARE @CorrelationID UNIQUEIDENTIFIER = NEWID();
DECLARE @EventID BIGINT;
DECLARE @EventSequence BIGINT;

-- Insert sample batch
INSERT INTO dbo.TransactionBatch (
    PartnerCode,
    Direction,
    TransactionType,
    FileName,
    FileHash,
    FileReceivedDate,
    BlobFullUri,
    InterchangeControlNumber,
    FunctionalGroupControlNumber,
    ProcessingStatus,
    ProcessingStartedUtc,
    ProcessingCompletedUtc,
    EventCount
)
VALUES (
    'PARTNERA',
    'INBOUND',
    '834',
    'PARTNERA_834_20251005_001.x12',
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    DATEADD(HOUR, -2, SYSUTCDATETIME()),
    'https://edistoragedev.blob.core.windows.net/inbound/PARTNERA_834_20251005_001.x12',
    '000000001',
    '000001',
    'COMPLETED',
    DATEADD(HOUR, -2, SYSUTCDATETIME()),
    DATEADD(HOUR, -1, DATEADD(MINUTE, -58, SYSUTCDATETIME())),
    0
);

SET @BatchID = SCOPE_IDENTITY();
PRINT CONCAT('  ✓ Created sample batch: TransactionBatchID = ', @BatchID);

-- Insert sample transaction header
INSERT INTO dbo.TransactionHeader (
    TransactionBatchID,
    TransactionSetControlNumber,
    PurposeCode,
    ReferenceIdentification,
    TransactionDate,
    SegmentCount,
    MemberCount,
    ProcessingStatus
)
VALUES (
    @BatchID,
    '0001',
    '00', -- Original
    'REF-834-001',
    CAST(SYSUTCDATETIME() AS DATE),
    45,
    2,
    'COMPLETED'
);

SET @HeaderID = SCOPE_IDENTITY();
PRINT CONCAT('  ✓ Created sample transaction header: TransactionHeaderID = ', @HeaderID);

-- =============================================
-- Seed Sample Events for Member 1
-- =============================================
DECLARE @Sub1 VARCHAR(50) = 'SUB123456789';

-- Event 1: MemberAdded
EXEC dbo.usp_AppendEvent
    @TransactionBatchID = @BatchID,
    @TransactionHeaderID = @HeaderID,
    @AggregateType = 'Member',
    @AggregateID = @Sub1,
    @EventType = 'MemberAdded',
    @EventVersion = 1,
    @EventData = N'{
        "subscriberID": "SUB123456789",
        "firstName": "John",
        "middleName": "Robert",
        "lastName": "Smith",
        "dateOfBirth": "1985-03-15",
        "gender": "M",
        "ssn": "123-45-6789",
        "relationshipCode": "18",
        "address": {
            "line1": "123 Main St",
            "line2": "Apt 4B",
            "city": "Springfield",
            "state": "IL",
            "zipCode": "62701"
        },
        "phone": "555-123-4567",
        "email": "john.smith@email.com"
    }',
    @EventMetadata = N'{
        "source": "834_transaction",
        "partnerId": "PARTNERA",
        "transactionControlNumber": "0001",
        "processingVersion": "1.0"
    }',
    @CorrelationID = @CorrelationID,
    @EventID = @EventID OUTPUT,
    @EventSequence = @EventSequence OUTPUT;

PRINT CONCAT('  ✓ Created MemberAdded event: EventID = ', @EventID, ', Sequence = ', @EventSequence);

-- Event 2: EnrollmentAdded
EXEC dbo.usp_AppendEvent
    @TransactionBatchID = @BatchID,
    @TransactionHeaderID = @HeaderID,
    @AggregateType = 'Enrollment',
    @AggregateID = @Sub1,
    @EventType = 'EnrollmentAdded',
    @EventVersion = 1,
    @EventData = N'{
        "subscriberID": "SUB123456789",
        "effectiveDate": "2025-01-01",
        "maintenanceTypeCode": "021",
        "maintenanceReasonCode": "01",
        "benefitStatusCode": "A",
        "groupNumber": "GRP12345",
        "planIdentifier": "PLAN-A-001"
    }',
    @EventMetadata = N'{
        "source": "834_transaction",
        "partnerId": "PARTNERA",
        "transactionControlNumber": "0001"
    }',
    @CorrelationID = @CorrelationID,
    @EventID = @EventID OUTPUT,
    @EventSequence = @EventSequence OUTPUT;

PRINT CONCAT('  ✓ Created EnrollmentAdded event: EventID = ', @EventID, ', Sequence = ', @EventSequence);

-- =============================================
-- Seed Sample Events for Member 2 (Dependent)
-- =============================================
DECLARE @Sub2 VARCHAR(50) = 'SUB123456789-01';

-- Event 3: MemberAdded (Dependent)
EXEC dbo.usp_AppendEvent
    @TransactionBatchID = @BatchID,
    @TransactionHeaderID = @HeaderID,
    @AggregateType = 'Member',
    @AggregateID = @Sub2,
    @EventType = 'MemberAdded',
    @EventVersion = 1,
    @EventData = N'{
        "subscriberID": "SUB123456789-01",
        "memberSuffix": "01",
        "firstName": "Jane",
        "lastName": "Smith",
        "dateOfBirth": "1987-07-22",
        "gender": "F",
        "relationshipCode": "01",
        "address": {
            "line1": "123 Main St",
            "line2": "Apt 4B",
            "city": "Springfield",
            "state": "IL",
            "zipCode": "62701"
        }
    }',
    @EventMetadata = N'{
        "source": "834_transaction",
        "partnerId": "PARTNERA",
        "transactionControlNumber": "0001",
        "relationshipToSubscriber": "Spouse"
    }',
    @CorrelationID = @CorrelationID,
    @EventID = @EventID OUTPUT,
    @EventSequence = @EventSequence OUTPUT;

PRINT CONCAT('  ✓ Created MemberAdded event (dependent): EventID = ', @EventID, ', Sequence = ', @EventSequence);

-- Event 4: EnrollmentAdded (Dependent)
EXEC dbo.usp_AppendEvent
    @TransactionBatchID = @BatchID,
    @TransactionHeaderID = @HeaderID,
    @AggregateType = 'Enrollment',
    @AggregateID = @Sub2,
    @EventType = 'EnrollmentAdded',
    @EventVersion = 1,
    @EventData = N'{
        "subscriberID": "SUB123456789-01",
        "effectiveDate": "2025-01-01",
        "maintenanceTypeCode": "021",
        "benefitStatusCode": "A",
        "groupNumber": "GRP12345",
        "planIdentifier": "PLAN-A-001"
    }',
    @EventMetadata = N'{
        "source": "834_transaction",
        "partnerId": "PARTNERA",
        "transactionControlNumber": "0001"
    }',
    @CorrelationID = @CorrelationID,
    @EventID = @EventID OUTPUT,
    @EventSequence = @EventSequence OUTPUT;

PRINT CONCAT('  ✓ Created EnrollmentAdded event (dependent): EventID = ', @EventID, ', Sequence = ', @EventSequence);

-- =============================================
-- Update Projections
-- =============================================
PRINT '';
PRINT 'Updating projections from events...';

-- Project Member 1
EXEC dbo.usp_UpdateMemberProjection
    @SubscriberID = @Sub1,
    @FirstName = 'John',
    @MiddleName = 'Robert',
    @LastName = 'Smith',
    @DateOfBirth = '1985-03-15',
    @Gender = 'M',
    @SSN = '123-45-6789',
    @RelationshipCode = '18',
    @AddressLine1 = '123 Main St',
    @AddressLine2 = 'Apt 4B',
    @City = 'Springfield',
    @State = 'IL',
    @ZipCode = '62701',
    @PhoneNumber = '555-123-4567',
    @EmailAddress = 'john.smith@email.com',
    @LastEventSequence = (SELECT MAX(EventSequence) FROM dbo.DomainEvent WHERE AggregateID = @Sub1),
    @LastEventTimestamp = (SELECT MAX(EventTimestamp) FROM dbo.DomainEvent WHERE AggregateID = @Sub1),
    @IsActive = 1;

PRINT '  ✓ Updated Member projection: ' + @Sub1;

-- Project Enrollment 1
EXEC dbo.usp_UpdateEnrollmentProjection
    @SubscriberID = @Sub1,
    @EffectiveDate = '2025-01-01',
    @MaintenanceTypeCode = '021',
    @MaintenanceReasonCode = '01',
    @BenefitStatusCode = 'A',
    @GroupNumber = 'GRP12345',
    @PlanIdentifier = 'PLAN-A-001',
    @LastEventSequence = (SELECT MAX(EventSequence) FROM dbo.DomainEvent WHERE AggregateID = @Sub1 AND AggregateType = 'Enrollment'),
    @LastEventTimestamp = (SELECT MAX(EventTimestamp) FROM dbo.DomainEvent WHERE AggregateID = @Sub1 AND AggregateType = 'Enrollment');

PRINT '  ✓ Updated Enrollment projection: ' + @Sub1;

-- Project Member 2
EXEC dbo.usp_UpdateMemberProjection
    @SubscriberID = @Sub2,
    @FirstName = 'Jane',
    @LastName = 'Smith',
    @DateOfBirth = '1987-07-22',
    @Gender = 'F',
    @RelationshipCode = '01',
    @AddressLine1 = '123 Main St',
    @AddressLine2 = 'Apt 4B',
    @City = 'Springfield',
    @State = 'IL',
    @ZipCode = '62701',
    @LastEventSequence = (SELECT MAX(EventSequence) FROM dbo.DomainEvent WHERE AggregateID = @Sub2),
    @LastEventTimestamp = (SELECT MAX(EventTimestamp) FROM dbo.DomainEvent WHERE AggregateID = @Sub2),
    @IsActive = 1;

PRINT '  ✓ Updated Member projection: ' + @Sub2;

-- Project Enrollment 2
EXEC dbo.usp_UpdateEnrollmentProjection
    @SubscriberID = @Sub2,
    @EffectiveDate = '2025-01-01',
    @MaintenanceTypeCode = '021',
    @BenefitStatusCode = 'A',
    @GroupNumber = 'GRP12345',
    @PlanIdentifier = 'PLAN-A-001',
    @LastEventSequence = (SELECT MAX(EventSequence) FROM dbo.DomainEvent WHERE AggregateID = @Sub2 AND AggregateType = 'Enrollment'),
    @LastEventTimestamp = (SELECT MAX(EventTimestamp) FROM dbo.DomainEvent WHERE AggregateID = @Sub2 AND AggregateType = 'Enrollment');

PRINT '  ✓ Updated Enrollment projection: ' + @Sub2;

COMMIT;

PRINT '';
PRINT '========================================';
PRINT 'Enrollment Event Store seeded successfully!';
PRINT '';
PRINT 'Sample Data Summary:';
PRINT '  - 1 Transaction Batch (PARTNERA_834_20251005_001.x12)';
PRINT '  - 1 Transaction Header (834 Original)';
PRINT '  - 4 Domain Events (2 Members + 2 Enrollments)';
PRINT '  - 2 Member Projections';
PRINT '  - 2 Enrollment Projections';
PRINT '';
PRINT 'Test Queries:';
PRINT '  SELECT * FROM dbo.vw_ActiveEnrollments;';
PRINT '  SELECT * FROM dbo.vw_EventStream;';
PRINT '  SELECT * FROM dbo.vw_BatchProcessingSummary;';
PRINT '  EXEC dbo.usp_GetEventStream @AggregateType = ''Member'', @AggregateID = ''SUB123456789'';';
PRINT '========================================';
GO
