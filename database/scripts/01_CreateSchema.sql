-- =============================================
-- SimpleSmartMail Database Schema
-- SQL Server 2019+
-- =============================================

USE master;
GO

-- Create database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SimpleSmartMailDb')
BEGIN
    CREATE DATABASE SimpleSmartMailDb;
END
GO

USE SimpleSmartMailDb;
GO

-- =============================================
-- Create Schema: emailCampaign
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'emailCampaign')
BEGIN
    EXEC('CREATE SCHEMA [emailCampaign]');
    PRINT 'Schema [emailCampaign] created.';
END
GO

-- =============================================
-- Table: Emails
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Emails]') AND type in (N'U'))
BEGIN
    CREATE TABLE [emailCampaign].[Emails] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [FromAddress] NVARCHAR(255) NOT NULL,
        [FromName] NVARCHAR(255) NOT NULL,
        [ToAddress] NVARCHAR(255) NOT NULL,
        [ToName] NVARCHAR(255) NOT NULL,
        [Cc] NVARCHAR(MAX) NULL,
        [Bcc] NVARCHAR(MAX) NULL,
        [Subject] NVARCHAR(500) NOT NULL,
        [HtmlBody] NVARCHAR(MAX) NOT NULL,
        [TextBody] NVARCHAR(MAX) NULL,
        [Status] INT NOT NULL DEFAULT 0, -- EmailStatus enum
        [CampaignId] INT NULL,
        [TrackingId] UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        [OpenTracked] BIT NOT NULL DEFAULT 0,
        [OpenedAt] DATETIME2 NULL,
        [OpenCount] INT NOT NULL DEFAULT 0,
        [ClickTracked] BIT NOT NULL DEFAULT 0,
        [FirstClickedAt] DATETIME2 NULL,
        [ClickCount] INT NOT NULL DEFAULT 0,
        [ScheduledAt] DATETIME2 NULL,
        [SentAt] DATETIME2 NULL,
        [DeliveredAt] DATETIME2 NULL,
        [ErrorMessage] NVARCHAR(MAX) NULL,
        [RetryCount] INT NOT NULL DEFAULT 0,
        [IsValid] BIT NOT NULL DEFAULT 1,
        [ProviderUsed] NVARCHAR(50) NULL,
        [Metadata] NVARCHAR(MAX) NULL,
        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [UpdatedAt] DATETIME2 NULL,

        INDEX IX_Emails_CampaignId (CampaignId),
        INDEX IX_Emails_Status (Status),
        INDEX IX_Emails_TrackingId (TrackingId),
        INDEX IX_Emails_CreatedAt (CreatedAt)
    );
END
GO

-- =============================================
-- Table: EmailAttachments
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailAttachments]') AND type in (N'U'))
BEGIN
    CREATE TABLE [emailCampaign].[EmailAttachments] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [EmailId] INT NOT NULL,
        [FileName] NVARCHAR(255) NOT NULL,
        [ContentType] NVARCHAR(100) NOT NULL,
        [SizeInBytes] BIGINT NOT NULL,
        [Content] VARBINARY(MAX) NOT NULL,

        CONSTRAINT FK_EmailAttachments_Emails FOREIGN KEY (EmailId)
            REFERENCES [emailCampaign].[Emails](Id) ON DELETE CASCADE,
        INDEX IX_EmailAttachments_EmailId (EmailId)
    );
END
GO

-- =============================================
-- Table: EmailTemplates
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailTemplates]') AND type in (N'U'))
BEGIN
    CREATE TABLE [emailCampaign].[EmailTemplates] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [Name] NVARCHAR(255) NOT NULL,
        [Description] NVARCHAR(1000) NOT NULL,
        [Subject] NVARCHAR(500) NOT NULL,
        [HtmlTemplate] NVARCHAR(MAX) NOT NULL,
        [TextTemplate] NVARCHAR(MAX) NULL,
        [IsActive] BIT NOT NULL DEFAULT 1,
        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [UpdatedAt] DATETIME2 NULL,
        [CreatedBy] NVARCHAR(255) NOT NULL,
        [UpdatedBy] NVARCHAR(255) NULL,

        INDEX IX_EmailTemplates_IsActive (IsActive)
    );
END
GO

-- =============================================
-- Table: EmailCampaigns
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailCampaigns]') AND type in (N'U'))
BEGIN
    CREATE TABLE [emailCampaign].[EmailCampaigns] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [Name] NVARCHAR(255) NOT NULL,
        [Description] NVARCHAR(1000) NOT NULL,
        [Status] INT NOT NULL DEFAULT 0, -- CampaignStatus enum
        [FromAddress] NVARCHAR(255) NOT NULL,
        [FromName] NVARCHAR(255) NOT NULL,
        [Subject] NVARCHAR(500) NOT NULL,
        [HtmlTemplate] NVARCHAR(MAX) NOT NULL,
        [TextTemplate] NVARCHAR(MAX) NULL,
        [ScheduledStartDate] DATETIME2 NULL,
        [BatchSize] INT NULL,
        [MaxEmailsPerHour] INT NULL,
        [EnableOpenTracking] BIT NOT NULL DEFAULT 1,
        [EnableClickTracking] BIT NOT NULL DEFAULT 1,
        [TotalRecipients] INT NOT NULL DEFAULT 0,
        [EmailsSent] INT NOT NULL DEFAULT 0,
        [EmailsDelivered] INT NOT NULL DEFAULT 0,
        [EmailsOpened] INT NOT NULL DEFAULT 0,
        [EmailsClicked] INT NOT NULL DEFAULT 0,
        [EmailsFailed] INT NOT NULL DEFAULT 0,
        [StartedAt] DATETIME2 NULL,
        [CompletedAt] DATETIME2 NULL,
        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [UpdatedAt] DATETIME2 NULL,
        [CreatedBy] NVARCHAR(255) NOT NULL,
        [UpdatedBy] NVARCHAR(255) NULL,

        INDEX IX_EmailCampaigns_Status (Status),
        INDEX IX_EmailCampaigns_CreatedAt (CreatedAt)
    );
END
GO

-- =============================================
-- Table: EmailCampaignPrograms
-- Maps campaigns to programs (many-to-many)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailCampaignPrograms]') AND type in (N'U'))
BEGIN
    CREATE TABLE [emailCampaign].[EmailCampaignPrograms] (
        [EmailCampaignId] INT NOT NULL,
        [ProgramId] INT NOT NULL,
        [CreatedAtUtc] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [UpdatedAtUtc] DATETIME2 NULL,
        [CreatedBy] NVARCHAR(255) NOT NULL,
        [UpdatedBy] NVARCHAR(255) NULL,

        CONSTRAINT PK_EmailCampaignPrograms
            PRIMARY KEY (EmailCampaignId, ProgramId),

        CONSTRAINT FK_EmailCampaignPrograms_EmailCampaigns
            FOREIGN KEY ([EmailCampaignId])
            REFERENCES [emailCampaign].[EmailCampaigns] ([Id]) ON DELETE CASCADE,

        -- Note: FK to Programs table assumes it exists in dbo schema
        -- Uncomment when Programs table is available:
        -- CONSTRAINT FK_EmailCampaignPrograms_Programs
        --     FOREIGN KEY ([ProgramId])
        --     REFERENCES [dbo].[Programs] ([ProgramId])

        INDEX IX_EmailCampaignPrograms_ProgramId (ProgramId),
        INDEX IX_EmailCampaignPrograms_EmailCampaignId (EmailCampaignId)
    );
END
GO

-- =============================================
-- Table: CampaignRecipients
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[CampaignRecipients]') AND type in (N'U'))
BEGIN
    CREATE TABLE [emailCampaign].[CampaignRecipients] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [CampaignId] INT NOT NULL,
        [EmailAddress] NVARCHAR(255) NOT NULL,
        [RecipientName] NVARCHAR(255) NULL,
        [PersonalizationData] NVARCHAR(MAX) NULL, -- JSON
        [EmailId] INT NULL,
        [Sent] BIT NOT NULL DEFAULT 0,
        [SentAt] DATETIME2 NULL,

        CONSTRAINT FK_CampaignRecipients_Campaigns FOREIGN KEY (CampaignId)
            REFERENCES [emailCampaign].[EmailCampaigns](Id) ON DELETE CASCADE,
        INDEX IX_CampaignRecipients_CampaignId (CampaignId),
        INDEX IX_CampaignRecipients_Sent (Sent)
    );
END
GO

-- =============================================
-- Table: EmailClicks
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailClicks]') AND type in (N'U'))
BEGIN
    CREATE TABLE [emailCampaign].[EmailClicks] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
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
            REFERENCES [emailCampaign].[Emails](Id) ON DELETE CASCADE,
        INDEX IX_EmailClicks_EmailId (EmailId),
        INDEX IX_EmailClicks_CampaignId (CampaignId),
        INDEX IX_EmailClicks_TrackingId (TrackingId),
        INDEX IX_EmailClicks_ClickedAt (ClickedAt)
    );
END
GO

-- =============================================
-- Table: UnsubscribeRequests
-- ProgramId NULL = global unsubscribe from all programs
-- ProgramId specific value = unsubscribe from that program only
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[UnsubscribeRequests]') AND type in (N'U'))
BEGIN
    CREATE TABLE [emailCampaign].[UnsubscribeRequests] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [EmailAddress] NVARCHAR(255) NOT NULL,
        [ProgramId] INT NULL, -- NULL = global unsubscribe
        [CampaignId] INT NULL,
        [EmailId] INT NULL,
        [TrackingId] UNIQUEIDENTIFIER NULL,
        [UnsubscribedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [Reason] NVARCHAR(MAX) NULL,
        [IpAddress] NVARCHAR(50) NULL,
        [UserAgent] NVARCHAR(MAX) NULL,

        -- Note: FK to Programs table assumes it exists in dbo schema
        -- Uncomment when Programs table is available:
        -- CONSTRAINT FK_UnsubscribeRequests_Programs
        --     FOREIGN KEY ([ProgramId])
        --     REFERENCES [dbo].[Programs] ([ProgramId])

        INDEX IX_UnsubscribeRequests_EmailAddress (EmailAddress),
        INDEX IX_UnsubscribeRequests_ProgramId (ProgramId),
        INDEX IX_UnsubscribeRequests_CampaignId (CampaignId)
    );
END
GO

PRINT 'Database schema created successfully!';
GO
