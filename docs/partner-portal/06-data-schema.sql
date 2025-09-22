-- Data Schema Draft (v0.1)
-- Purpose: Define initial Azure SQL relational structures for Partner Portal.
-- Naming: singular table names, PascalCase columns, clustered PK on surrogate GUID unless noted.
-- Retention: Business decision pending; archival strategy TBD (OPEN in docs).

CREATE TABLE TradingPartner (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL UNIQUE,
    Status VARCHAR(20) NOT NULL DEFAULT 'active',
    DefaultSLAProfileRef NVARCHAR(100) NULL,
    CreatedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE PartnerUser (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    PartnerId UNIQUEIDENTIFIER NOT NULL REFERENCES TradingPartner(Id),
    Email NVARCHAR(320) NOT NULL,
    NormalizedEmail AS LOWER(Email) PERSISTED,
    Role VARCHAR(20) NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'active',
    MfaEnabled BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    LastLoginAt DATETIME2(3) NULL,
    CONSTRAINT UQ_PartnerUser_Email UNIQUE (PartnerId, NormalizedEmail)
);
CREATE INDEX IX_PartnerUser_Partner ON PartnerUser(PartnerId);

CREATE TABLE PgpKey (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    PartnerId UNIQUEIDENTIFIER NOT NULL REFERENCES TradingPartner(Id),
    Fingerprint CHAR(40) NOT NULL,
    UploadedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    ExpiresAt DATETIME2(3) NULL,
    Status VARCHAR(20) NOT NULL,
    [Version] INT NOT NULL,
    CONSTRAINT UQ_PgpKey_Fingerprint UNIQUE (PartnerId, Fingerprint)
);
CREATE INDEX IX_PgpKey_Partner_Status ON PgpKey(PartnerId, Status);

CREATE TABLE SftpCredential (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    PartnerId UNIQUEIDENTIFIER NOT NULL REFERENCES TradingPartner(Id),
    Type VARCHAR(20) NOT NULL, -- Password | SSHKey
    Fingerprint NVARCHAR(200) NULL, -- if key type
    CreatedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    RotatedAt DATETIME2(3) NULL,
    ExpiresAt DATETIME2(3) NULL,
    Status VARCHAR(30) NOT NULL,
    CONSTRAINT UQ_SftpCredential_Active UNIQUE (PartnerId, Type, Status) WHERE Status = 'active'
);
CREATE INDEX IX_SftpCredential_Partner_Type ON SftpCredential(PartnerId, Type);

CREATE TABLE RotationRequest (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    PartnerId UNIQUEIDENTIFIER NOT NULL REFERENCES TradingPartner(Id),
    CredentialType VARCHAR(20) NOT NULL, -- maps to SftpCredential.Type
    RequestedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    RequestedBy UNIQUEIDENTIFIER NOT NULL REFERENCES PartnerUser(Id),
    Note NVARCHAR(500) NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Requested' -- Requested|InProgress|Completed|Rejected
);
CREATE INDEX IX_RotationRequest_Partner_Status ON RotationRequest(PartnerId, Status);

CREATE TABLE AlertPreference (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    PartnerUserId UNIQUEIDENTIFIER NOT NULL REFERENCES PartnerUser(Id),
    Category VARCHAR(30) NOT NULL, -- latency|rejects|anomalies|backlog|keyExpiry
    Channel VARCHAR(30) NOT NULL, -- email
    Enabled BIT NOT NULL,
    UpdatedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_AlertPreference_User_Category UNIQUE (PartnerUserId, Category)
);
CREATE INDEX IX_AlertPreference_User ON AlertPreference(PartnerUserId);

CREATE TABLE AuditEvent (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    PartnerId UNIQUEIDENTIFIER NOT NULL REFERENCES TradingPartner(Id),
    ActorUserId UNIQUEIDENTIFIER NOT NULL REFERENCES PartnerUser(Id),
    ActionType VARCHAR(50) NOT NULL,
    TargetType VARCHAR(50) NOT NULL,
    TargetId NVARCHAR(100) NULL,
    Timestamp DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId UNIQUEIDENTIFIER NOT NULL,
    Metadata NVARCHAR(MAX) NULL
);
CREATE INDEX IX_AuditEvent_Partner_Time ON AuditEvent(PartnerId, Timestamp DESC);
CREATE INDEX IX_AuditEvent_Partner_Action ON AuditEvent(PartnerId, ActionType);

-- Read model tables optional; may instead query external logs.
-- Potential materialized view placeholder:
-- CREATE VIEW PartnerActivePgpKey AS SELECT * FROM PgpKey WHERE Status = 'active';

-- OPEN: Evaluate partitioning or temporal tables if data volume grows.
