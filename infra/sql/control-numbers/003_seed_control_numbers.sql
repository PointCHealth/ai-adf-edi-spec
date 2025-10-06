/*
    Control Number Store - Initial Seed Data
    Run after schema and procedures are deployed
*/

SET XACT_ABORT ON;
GO

BEGIN TRAN;

-- Seed initial control number counters for common partners and transaction types
-- These will be auto-created on first use, but pre-seeding improves first-call performance

PRINT 'Seeding initial control number counters...';

-- Partner A - Full transaction set
MERGE INTO dbo.ControlNumberCounters AS target
USING (
    SELECT 'PARTNERA' AS PartnerCode, '270' AS TransactionType, 'ISA' AS CounterType UNION ALL
    SELECT 'PARTNERA', '270', 'GS' UNION ALL
    SELECT 'PARTNERA', '270', 'ST' UNION ALL
    SELECT 'PARTNERA', '271', 'ISA' UNION ALL
    SELECT 'PARTNERA', '271', 'GS' UNION ALL
    SELECT 'PARTNERA', '271', 'ST' UNION ALL
    SELECT 'PARTNERA', '837', 'ISA' UNION ALL
    SELECT 'PARTNERA', '837', 'GS' UNION ALL
    SELECT 'PARTNERA', '837', 'ST' UNION ALL
    SELECT 'PARTNERA', '835', 'ISA' UNION ALL
    SELECT 'PARTNERA', '835', 'GS' UNION ALL
    SELECT 'PARTNERA', '835', 'ST'
) AS source (PartnerCode, TransactionType, CounterType)
ON target.PartnerCode = source.PartnerCode 
   AND target.TransactionType = source.TransactionType 
   AND target.CounterType = source.CounterType
WHEN NOT MATCHED THEN
    INSERT (PartnerCode, TransactionType, CounterType, CurrentValue)
    VALUES (source.PartnerCode, source.TransactionType, source.CounterType, 1);

-- Partner B - Eligibility only
MERGE INTO dbo.ControlNumberCounters AS target
USING (
    SELECT 'PARTNERB' AS PartnerCode, '270' AS TransactionType, 'ISA' AS CounterType UNION ALL
    SELECT 'PARTNERB', '270', 'GS' UNION ALL
    SELECT 'PARTNERB', '270', 'ST' UNION ALL
    SELECT 'PARTNERB', '271', 'ISA' UNION ALL
    SELECT 'PARTNERB', '271', 'GS' UNION ALL
    SELECT 'PARTNERB', '271', 'ST'
) AS source (PartnerCode, TransactionType, CounterType)
ON target.PartnerCode = source.PartnerCode 
   AND target.TransactionType = source.TransactionType 
   AND target.CounterType = source.CounterType
WHEN NOT MATCHED THEN
    INSERT (PartnerCode, TransactionType, CounterType, CurrentValue)
    VALUES (source.PartnerCode, source.TransactionType, source.CounterType, 1);

-- Internal Claims - Outbound acknowledgments
MERGE INTO dbo.ControlNumberCounters AS target
USING (
    SELECT 'INTERNAL-CLAIMS' AS PartnerCode, '277' AS TransactionType, 'ISA' AS CounterType UNION ALL
    SELECT 'INTERNAL-CLAIMS', '277', 'GS' UNION ALL
    SELECT 'INTERNAL-CLAIMS', '277', 'ST' UNION ALL
    SELECT 'INTERNAL-CLAIMS', '999', 'ISA' UNION ALL
    SELECT 'INTERNAL-CLAIMS', '999', 'GS' UNION ALL
    SELECT 'INTERNAL-CLAIMS', '999', 'ST'
) AS source (PartnerCode, TransactionType, CounterType)
ON target.PartnerCode = source.PartnerCode 
   AND target.TransactionType = source.TransactionType 
   AND target.CounterType = source.CounterType
WHEN NOT MATCHED THEN
    INSERT (PartnerCode, TransactionType, CounterType, CurrentValue)
    VALUES (source.PartnerCode, source.TransactionType, source.CounterType, 1);

-- Test Partner
MERGE INTO dbo.ControlNumberCounters AS target
USING (
    SELECT 'TEST001' AS PartnerCode, '270' AS TransactionType, 'ISA' AS CounterType UNION ALL
    SELECT 'TEST001', '270', 'GS' UNION ALL
    SELECT 'TEST001', '270', 'ST' UNION ALL
    SELECT 'TEST001', '271', 'ISA' UNION ALL
    SELECT 'TEST001', '271', 'GS' UNION ALL
    SELECT 'TEST001', '271', 'ST'
) AS source (PartnerCode, TransactionType, CounterType)
ON target.PartnerCode = source.PartnerCode 
   AND target.TransactionType = source.TransactionType 
   AND target.CounterType = source.CounterType
WHEN NOT MATCHED THEN
    INSERT (PartnerCode, TransactionType, CounterType, CurrentValue)
    VALUES (source.PartnerCode, source.TransactionType, source.CounterType, 1);

DECLARE @RowsInserted INT = @@ROWCOUNT;

COMMIT;

PRINT CONCAT('Successfully seeded ', @RowsInserted, ' control number counters.');
GO
