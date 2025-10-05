# AI Prompt: Create Integration Test Suite

## Objective

Create comprehensive integration test projects across all repositories to validate end-to-end EDI transaction flows.

## Prerequisites

- All function projects created and deployed to dev environment
- Shared libraries available
- Test data available (sample EDI files)
- Azure resources deployed in dev environment

## Prompt

```text
I need you to create integration test projects for the EDI Healthcare Platform that validate end-to-end transaction flows across all components.

Context:
- Testing Framework: xUnit with Testcontainers for Azure emulators
- Test Environment: Dev environment with actual Azure resources
- Approach: Black-box testing with real EDI files
- CI/CD: Run on every PR and nightly builds
- Coverage: End-to-end flows from file ingestion to partner delivery
- Timeline: 18-week AI-accelerated implementation

Please create integration test projects in the following repositories:

---

## Repository: edi-platform-core

### Project: Integration.Tests

Location: `tests/Integration.Tests/Integration.Tests.csproj`

Structure:
```text
tests/Integration.Tests/
├── Integration.Tests.csproj
├── Fixtures/
│   ├── AzureTestFixture.cs (setup Azure resources)
│   ├── FunctionAppFixture.cs (deploy functions locally)
│   └── TestDataFixture.cs (load test data)
├── Tests/
│   ├── InboundRouterTests.cs
│   ├── EnterpriseSchedulerTests.cs
│   └── EndToEndFlowTests.cs
├── Helpers/
│   ├── BlobStorageHelper.cs
│   ├── ServiceBusHelper.cs
│   └── SqlDatabaseHelper.cs
├── TestData/
│   ├── sample-270.edi
│   ├── sample-834.edi
│   └── sample-837.edi
└── appsettings.test.json
```

Test Scenarios:

**InboundRouterTests.cs:**
- Test 1: Upload EDI file to inbound container → Verify routing message published
- Test 2: Invalid EDI file → Verify moved to quarantine
- Test 3: Routing with different transaction types → Verify correct queue assignments
- Test 4: Large file (>10MB) → Verify chunked processing
- Test 5: Concurrent file uploads → Verify no race conditions

**EnterpriseSchedulerTests.cs:**
- Test 1: Timer trigger fires → Verify job executed
- Test 2: Manual RunNow trigger → Verify job executed immediately
- Test 3: Job failure → Verify retry logic and notifications
- Test 4: Scheduled job history → Verify audit trail in database

**EndToEndFlowTests.cs:**
- Test 1: 270 Eligibility flow (inbound → routing → mapper → connector → outbound)
- Test 2: 834 Enrollment flow with event sourcing
- Test 3: 837 Claims flow with acknowledgment generation
- Test 4: Multiple partners processing simultaneously

Requirements:
- Use `IClassFixture<T>` for shared setup/teardown
- Clean up Azure resources after tests
- Use Polly for retry logic in tests
- Capture detailed logs for debugging
- Run tests in parallel where safe

Dependencies:
- xUnit
- FluentAssertions
- Testcontainers.Azurite (for local storage emulation)
- Microsoft.Extensions.Configuration
- Azure SDKs (Blob, ServiceBus, SQL)

---

## Repository: edi-mappers

### Project: Integration.Tests

Location: `tests/Integration.Tests/Integration.Tests.csproj`

Test Scenarios:

**EligibilityMapperTests.cs:**
- Test 1: Valid 270 X12 → Canonical model → Partner JSON
- Test 2: Valid 271 partner response → Canonical model → X12
- Test 3: Invalid X12 format → Verify error handling and dead-letter
- Test 4: Missing required fields → Verify validation errors
- Test 5: Large batch of transactions → Verify throughput

**ClaimsMapperTests.cs:**
- Test 1: Professional claim (837P) → Partner format
- Test 2: Institutional claim (837I) → Partner format
- Test 3: Dental claim (837D) → Partner format
- Test 4: Claim with attachments → Verify attachment handling
- Test 5: Claim adjustment → Verify change tracking

**EnrollmentMapperTests.cs:**
- Test 1: New enrollment (834) → Event sourcing
- Test 2: Enrollment change → Event append
- Test 3: Enrollment termination → Event append
- Test 4: Query enrollment history → Verify event replay
- Test 5: Concurrent enrollment updates → Verify consistency

**RemittanceMapperTests.cs:**
- Test 1: 835 remittance → Payment posting format
- Test 2: Bulk remittance file → Individual transactions
- Test 3: Remittance with adjustments → Verify calculations

---

## Repository: edi-connectors

### Project: Integration.Tests

Location: `tests/Integration.Tests/Integration.Tests.csproj`

Test Scenarios:

**SftpConnectorTests.cs:**
- Test 1: Upload file to partner SFTP → Verify delivery
- Test 2: Download file from partner SFTP → Verify receipt
- Test 3: SFTP connection failure → Verify retry logic
- Test 4: Large file transfer (>50MB) → Verify streaming
- Test 5: Concurrent transfers → Verify no file corruption

Note: Use Testcontainers for SFTP server or mock SFTP service

**ApiConnectorTests.cs:**
- Test 1: POST to partner API → Verify response
- Test 2: GET from partner API → Verify data retrieval
- Test 3: API authentication failure → Verify error handling
- Test 4: API rate limiting → Verify backoff strategy
- Test 5: Timeout handling → Verify circuit breaker

**DatabaseConnectorTests.cs:**
- Test 1: Write to partner database → Verify record created
- Test 2: Read from partner database → Verify data retrieval
- Test 3: Transaction rollback on error → Verify atomicity

---

## Cross-Repository End-to-End Tests

Create special test project: `edi-platform-core/tests/E2E.Tests`

Test Scenarios:

**CompleteTransactionFlowTests.cs:**

Test: 270 Eligibility Full Flow
1. Upload 270 X12 file to inbound SFTP
2. Verify InboundRouter picks up file
3. Verify routing message published to Service Bus
4. Verify EligibilityMapper transforms to partner format
5. Verify ApiConnector sends to partner API
6. Simulate partner 271 response
7. Verify InboundMapper transforms back to X12
8. Verify 271 file delivered to outbound SFTP
9. Verify audit trail in all systems
10. Verify end-to-end latency <5 minutes

Test: 834 Enrollment with Event Sourcing
1. Upload 834 X12 file (new enrollment)
2. Verify event stored in event store
3. Upload 834 X12 file (change enrollment)
4. Verify event appended
5. Query enrollment history
6. Verify event replay reconstructs current state

Test: Multi-Partner Concurrent Processing
1. Upload 100 files for 5 different partners
2. Verify all files routed correctly
3. Verify no partner data leakage
4. Verify SLA compliance for all partners

---

## Common Requirements for ALL Integration Tests

1. **Test Data Management:**
   - Store test EDI files in `TestData/` directory
   - Use realistic but anonymized data (no PHI)
   - Generate test data with faker libraries if needed
   - Version control test data

2. **Environment Configuration:**
   - Use `appsettings.test.json` for test configuration
   - Support local dev environment and CI environment
   - Use Azure Dev/Test resources (not production)
   - Configure via environment variables in CI

3. **Test Isolation:**
   - Use unique identifiers for test data (e.g., timestamp prefix)
   - Clean up resources after tests (blob, queue, database)
   - Use transactions where possible
   - Implement `IAsyncLifetime` for async setup/teardown

4. **Assertions:**
   - Use FluentAssertions for readable assertions
   - Assert on multiple properties, not just success
   - Capture and assert on logs
   - Verify database state, not just function return values

5. **Performance Validation:**
   - Assert on maximum execution time
   - Measure and log actual execution time
   - Track performance trends over time
   - Alert on performance regressions

6. **Error Scenarios:**
   - Test happy path AND error paths
   - Verify dead-letter queue handling
   - Verify retry logic
   - Verify error logging and notifications

7. **CI/CD Integration:**
   - Run on every PR (fast tests only)
   - Run nightly (all tests including slow ones)
   - Fail build on test failures
   - Generate test coverage reports
   - Publish test results to PR comments

Also provide:
1. PowerShell script to set up test environment
2. Docker Compose file for local Azure emulators (Azurite, SQL Edge)
3. GitHub Actions workflow for integration tests
4. Test data generator for creating sample EDI files
5. Troubleshooting guide for common test failures
```

## Expected Outcome

After running this prompt, you should have:

- ✅ Integration test projects in all repositories
- ✅ End-to-end test scenarios covering critical flows
- ✅ Test fixtures for Azure resources
- ✅ Test data management strategy
- ✅ CI/CD integration for automated testing
- ✅ Test execution scripts

## Validation Steps

1. Build all test projects:

   ```powershell
   cd edi-platform-core\tests\Integration.Tests
   dotnet build
   
   cd ..\..\..
   cd edi-mappers\tests\Integration.Tests
   dotnet build
   ```

2. Run tests locally (requires dev environment):

   ```powershell
   # Set test configuration
   $env:AZURE_STORAGE_CONNECTION_STRING = "UseDevelopmentStorage=true"
   $env:AZURE_SERVICEBUS_CONNECTION_STRING = "<dev-connection-string>"
   
   # Run tests
   cd edi-platform-core\tests\Integration.Tests
   dotnet test --logger "console;verbosity=detailed"
   ```

3. Run with Docker Compose (local emulators):

   ```powershell
   # Start local Azure emulators
   docker-compose -f docker-compose.test.yml up -d
   
   # Run tests
   dotnet test
   
   # Stop emulators
   docker-compose -f docker-compose.test.yml down
   ```

4. Test CI/CD workflow:

   ```powershell
   # Create test branch
   git checkout -b test/integration-tests
   
   # Push changes
   git add .
   git commit -m "test: Add integration tests"
   git push origin test/integration-tests
   
   # Create PR and watch tests run
   ```

## Troubleshooting

**Tests fail with connection errors:**

- Verify Azure emulators running (Azurite)
- Check connection strings in `appsettings.test.json`
- Ensure firewall allows connections to Azure resources
- Verify service principal has correct permissions

**Tests timeout:**

- Increase test timeout in xUnit: `[Fact(Timeout = 60000)]`
- Check Azure resource scale (may be throttled)
- Use asynchronous waiting (not Thread.Sleep)

**Flaky tests (intermittent failures):**

- Add retry logic with Polly
- Increase wait times for asynchronous operations
- Check for race conditions in test setup
- Ensure proper test isolation

**Test data conflicts:**

- Use unique identifiers for test data
- Implement cleanup in test teardown
- Check for leftover data from previous runs

## Next Steps

After successful completion:

- Run integration tests on every PR
- Track test coverage over time
- Add performance benchmarking tests [18-create-performance-tests.md](18-create-performance-tests.md)
- Create test data management strategy [23-test-data-management.md](../23-test-data-management.md)
- Set up test results dashboard
