-- =============================================
-- Tracking Tables and Stored Procedures
-- =============================================

USE SimpleSmartMailDb;
GO

-- =============================================
-- Table: Tenants
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tenants]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[Tenants] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [TenantId] NVARCHAR(50) NOT NULL UNIQUE,
        [Name] NVARCHAR(255) NOT NULL,
        [Description] NVARCHAR(1000) NOT NULL,
        [IsActive] BIT NOT NULL DEFAULT 1,
        [DefaultEmailProvider] INT NOT NULL DEFAULT 0,
        [MaxAttachmentSizeInMb] INT NOT NULL DEFAULT 25,
        [MaxEmailsPerHour] INT NULL,
        [MaxEmailsPerDay] INT NULL,
        [EnableOpenTracking] BIT NOT NULL DEFAULT 1,
        [EnableClickTracking] BIT NOT NULL DEFAULT 1,
        [ApiKey] NVARCHAR(255) NULL UNIQUE,
        [ApiKeyCreatedAt] DATETIME2 NULL,
        [ApiKeyExpiresAt] DATETIME2 NULL,
        [ContactEmail] NVARCHAR(255) NULL,
        [ContactName] NVARCHAR(255) NULL,
        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [UpdatedAt] DATETIME2 NULL,

        INDEX IX_Tenants_TenantId (TenantId),
        INDEX IX_Tenants_ApiKey (ApiKey),
        INDEX IX_Tenants_IsActive (IsActive)
    );
END
GO

-- =============================================
-- Table: EmailClicks
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EmailClicks]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[EmailClicks] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [TenantId] NVARCHAR(50) NOT NULL,
        [EmailId] INT NOT NULL,
        [CampaignId] INT NULL,
        [TrackingId] UNIQUEIDENTIFIER NOT NULL,
        [RecipientEmail] NVARCHAR(255) NOT NULL,
        [OriginalUrl] NVARCHAR(MAX) NOT NULL,
        [TrackedUrl] NVARCHAR(MAX) NOT NULL,
        [ClickedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [IpAddress] NVARCHAR(50) NULL,
        [UserAgent] NVARCHAR(MAX) NULL,
        [Country] NVARCHAR(100) NULL,
        [City] NVARCHAR(100) NULL,
        [Device] NVARCHAR(50) NULL,

        CONSTRAINT FK_EmailClicks_Emails FOREIGN KEY (EmailId)
            REFERENCES Emails(Id) ON DELETE CASCADE,
        INDEX IX_EmailClicks_EmailId (EmailId),
        INDEX IX_EmailClicks_CampaignId (CampaignId),
        INDEX IX_EmailClicks_TrackingId (TrackingId),
        INDEX IX_EmailClicks_ClickedAt (ClickedAt)
    );
END
GO

-- =============================================
-- Table: UnsubscribeRequests
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UnsubscribeRequests]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[UnsubscribeRequests] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [TenantId] NVARCHAR(50) NOT NULL,
        [EmailAddress] NVARCHAR(255) NOT NULL,
        [CampaignId] INT NULL,
        [EmailId] INT NULL,
        [TrackingId] UNIQUEIDENTIFIER NULL,
        [UnsubscribedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [Reason] NVARCHAR(MAX) NULL,
        [IpAddress] NVARCHAR(50) NULL,
        [UserAgent] NVARCHAR(MAX) NULL,
        [GlobalUnsubscribe] BIT NOT NULL DEFAULT 0,

        INDEX IX_UnsubscribeRequests_EmailAddress (EmailAddress),
        INDEX IX_UnsubscribeRequests_TenantId (TenantId),
        INDEX IX_UnsubscribeRequests_CampaignId (CampaignId)
    );
END
GO

-- =============================================
-- sp_Tenant_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Tenant_Create]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Tenant_Create];
GO

CREATE PROCEDURE [dbo].[sp_Tenant_Create]
    @TenantId NVARCHAR(50),
    @Name NVARCHAR(255),
    @Description NVARCHAR(1000),
    @IsActive BIT,
    @DefaultEmailProvider INT,
    @MaxAttachmentSizeInMb INT,
    @MaxEmailsPerHour INT = NULL,
    @MaxEmailsPerDay INT = NULL,
    @EnableOpenTracking BIT,
    @EnableClickTracking BIT,
    @ApiKey NVARCHAR(255) = NULL,
    @ApiKeyExpiresAt DATETIME2 = NULL,
    @ContactEmail NVARCHAR(255) = NULL,
    @ContactName NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Tenants (
        TenantId, Name, Description, IsActive,
        DefaultEmailProvider, MaxAttachmentSizeInMb,
        MaxEmailsPerHour, MaxEmailsPerDay,
        EnableOpenTracking, EnableClickTracking,
        ApiKey, ApiKeyCreatedAt, ApiKeyExpiresAt,
        ContactEmail, ContactName, CreatedAt
    )
    VALUES (
        @TenantId, @Name, @Description, @IsActive,
        @DefaultEmailProvider, @MaxAttachmentSizeInMb,
        @MaxEmailsPerHour, @MaxEmailsPerDay,
        @EnableOpenTracking, @EnableClickTracking,
        @ApiKey, CASE WHEN @ApiKey IS NOT NULL THEN GETUTCDATE() ELSE NULL END, @ApiKeyExpiresAt,
        @ContactEmail, @ContactName, GETUTCDATE()
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS TenantDbId;
END
GO

-- =============================================
-- sp_Tenant_GetById
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Tenant_GetById]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Tenant_GetById];
GO

CREATE PROCEDURE [dbo].[sp_Tenant_GetById]
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, Name, Description, IsActive,
        DefaultEmailProvider, MaxAttachmentSizeInMb,
        MaxEmailsPerHour, MaxEmailsPerDay,
        EnableOpenTracking, EnableClickTracking,
        ApiKey, ApiKeyCreatedAt, ApiKeyExpiresAt,
        ContactEmail, ContactName,
        CreatedAt, UpdatedAt
    FROM Tenants
    WHERE Id = @Id;
END
GO

-- =============================================
-- sp_Tenant_GetByTenantId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Tenant_GetByTenantId]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Tenant_GetByTenantId];
GO

CREATE PROCEDURE [dbo].[sp_Tenant_GetByTenantId]
    @TenantId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, Name, Description, IsActive,
        DefaultEmailProvider, MaxAttachmentSizeInMb,
        MaxEmailsPerHour, MaxEmailsPerDay,
        EnableOpenTracking, EnableClickTracking,
        ApiKey, ApiKeyCreatedAt, ApiKeyExpiresAt,
        ContactEmail, ContactName,
        CreatedAt, UpdatedAt
    FROM Tenants
    WHERE TenantId = @TenantId;
END
GO

-- =============================================
-- sp_Tenant_GetByApiKey
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Tenant_GetByApiKey]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Tenant_GetByApiKey];
GO

CREATE PROCEDURE [dbo].[sp_Tenant_GetByApiKey]
    @ApiKey NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, Name, Description, IsActive,
        DefaultEmailProvider, MaxAttachmentSizeInMb,
        MaxEmailsPerHour, MaxEmailsPerDay,
        EnableOpenTracking, EnableClickTracking,
        ApiKey, ApiKeyCreatedAt, ApiKeyExpiresAt,
        ContactEmail, ContactName,
        CreatedAt, UpdatedAt
    FROM Tenants
    WHERE ApiKey = @ApiKey
      AND IsActive = 1
      AND (ApiKeyExpiresAt IS NULL OR ApiKeyExpiresAt > GETUTCDATE());
END
GO

-- =============================================
-- sp_Tenant_Update
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Tenant_Update]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Tenant_Update];
GO

CREATE PROCEDURE [dbo].[sp_Tenant_Update]
    @Id INT,
    @Name NVARCHAR(255),
    @Description NVARCHAR(1000),
    @IsActive BIT,
    @DefaultEmailProvider INT,
    @MaxAttachmentSizeInMb INT,
    @MaxEmailsPerHour INT = NULL,
    @MaxEmailsPerDay INT = NULL,
    @EnableOpenTracking BIT,
    @EnableClickTracking BIT,
    @ApiKey NVARCHAR(255) = NULL,
    @ApiKeyExpiresAt DATETIME2 = NULL,
    @ContactEmail NVARCHAR(255) = NULL,
    @ContactName NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Tenants
    SET
        Name = @Name,
        Description = @Description,
        IsActive = @IsActive,
        DefaultEmailProvider = @DefaultEmailProvider,
        MaxAttachmentSizeInMb = @MaxAttachmentSizeInMb,
        MaxEmailsPerHour = @MaxEmailsPerHour,
        MaxEmailsPerDay = @MaxEmailsPerDay,
        EnableOpenTracking = @EnableOpenTracking,
        EnableClickTracking = @EnableClickTracking,
        ApiKey = @ApiKey,
        ApiKeyExpiresAt = @ApiKeyExpiresAt,
        ContactEmail = @ContactEmail,
        ContactName = @ContactName,
        UpdatedAt = GETUTCDATE()
    WHERE Id = @Id;
END
GO

-- =============================================
-- sp_Tracking_RecordOpen
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Tracking_RecordOpen]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Tracking_RecordOpen];
GO

CREATE PROCEDURE [dbo].[sp_Tracking_RecordOpen]
    @TrackingId UNIQUEIDENTIFIER,
    @IpAddress NVARCHAR(50) = NULL,
    @UserAgent NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Update the email record
    UPDATE Emails
    SET
        OpenTracked = 1,
        OpenedAt = CASE WHEN OpenedAt IS NULL THEN GETUTCDATE() ELSE OpenedAt END,
        OpenCount = OpenCount + 1,
        Status = CASE WHEN Status < 4 THEN 4 ELSE Status END, -- 4 = Opened
        UpdatedAt = GETUTCDATE()
    WHERE TrackingId = @TrackingId;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

-- =============================================
-- sp_Tracking_RecordClick
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Tracking_RecordClick]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Tracking_RecordClick];
GO

CREATE PROCEDURE [dbo].[sp_Tracking_RecordClick]
    @TenantId NVARCHAR(50),
    @EmailId INT,
    @CampaignId INT = NULL,
    @TrackingId UNIQUEIDENTIFIER,
    @RecipientEmail NVARCHAR(255),
    @OriginalUrl NVARCHAR(MAX),
    @TrackedUrl NVARCHAR(MAX),
    @IpAddress NVARCHAR(50) = NULL,
    @UserAgent NVARCHAR(MAX) = NULL,
    @Country NVARCHAR(100) = NULL,
    @City NVARCHAR(100) = NULL,
    @Device NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO EmailClicks (
        TenantId, EmailId, CampaignId, TrackingId,
        RecipientEmail, OriginalUrl, TrackedUrl,
        ClickedAt, IpAddress, UserAgent,
        Country, City, Device
    )
    VALUES (
        @TenantId, @EmailId, @CampaignId, @TrackingId,
        @RecipientEmail, @OriginalUrl, @TrackedUrl,
        GETUTCDATE(), @IpAddress, @UserAgent,
        @Country, @City, @Device
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS ClickId;
END
GO

-- =============================================
-- sp_Tracking_GetClicksByEmailId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Tracking_GetClicksByEmailId]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Tracking_GetClicksByEmailId];
GO

CREATE PROCEDURE [dbo].[sp_Tracking_GetClicksByEmailId]
    @EmailId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, EmailId, CampaignId, TrackingId,
        RecipientEmail, OriginalUrl, TrackedUrl,
        ClickedAt, IpAddress, UserAgent,
        Country, City, Device
    FROM EmailClicks
    WHERE EmailId = @EmailId
    ORDER BY ClickedAt DESC;
END
GO

-- =============================================
-- sp_Tracking_GetClicksByCampaignId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Tracking_GetClicksByCampaignId]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Tracking_GetClicksByCampaignId];
GO

CREATE PROCEDURE [dbo].[sp_Tracking_GetClicksByCampaignId]
    @CampaignId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, EmailId, CampaignId, TrackingId,
        RecipientEmail, OriginalUrl, TrackedUrl,
        ClickedAt, IpAddress, UserAgent,
        Country, City, Device
    FROM EmailClicks
    WHERE CampaignId = @CampaignId
    ORDER BY ClickedAt DESC;
END
GO

-- =============================================
-- sp_Unsubscribe_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Unsubscribe_Create]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Unsubscribe_Create];
GO

CREATE PROCEDURE [dbo].[sp_Unsubscribe_Create]
    @TenantId NVARCHAR(50),
    @EmailAddress NVARCHAR(255),
    @CampaignId INT = NULL,
    @EmailId INT = NULL,
    @TrackingId UNIQUEIDENTIFIER = NULL,
    @Reason NVARCHAR(MAX) = NULL,
    @IpAddress NVARCHAR(50) = NULL,
    @UserAgent NVARCHAR(MAX) = NULL,
    @GlobalUnsubscribe BIT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO UnsubscribeRequests (
        TenantId, EmailAddress, CampaignId, EmailId, TrackingId,
        UnsubscribedAt, Reason, IpAddress, UserAgent, GlobalUnsubscribe
    )
    VALUES (
        @TenantId, @EmailAddress, @CampaignId, @EmailId, @TrackingId,
        GETUTCDATE(), @Reason, @IpAddress, @UserAgent, @GlobalUnsubscribe
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS RequestId;
END
GO

-- =============================================
-- sp_Unsubscribe_IsUnsubscribed
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Unsubscribe_IsUnsubscribed]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Unsubscribe_IsUnsubscribed];
GO

CREATE PROCEDURE [dbo].[sp_Unsubscribe_IsUnsubscribed]
    @EmailAddress NVARCHAR(255),
    @TenantId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS IsUnsubscribed
    FROM UnsubscribeRequests
    WHERE EmailAddress = @EmailAddress
      AND TenantId = @TenantId
      AND GlobalUnsubscribe = 1;
END
GO

-- =============================================
-- sp_Unsubscribe_GetByTenantId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Unsubscribe_GetByTenantId]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Unsubscribe_GetByTenantId];
GO

CREATE PROCEDURE [dbo].[sp_Unsubscribe_GetByTenantId]
    @TenantId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, EmailAddress, CampaignId, EmailId, TrackingId,
        UnsubscribedAt, Reason, IpAddress, UserAgent, GlobalUnsubscribe
    FROM UnsubscribeRequests
    WHERE TenantId = @TenantId
    ORDER BY UnsubscribedAt DESC;
END
GO

PRINT 'Tracking tables and stored procedures created successfully!';
GO
