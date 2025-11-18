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
-- Table: Emails
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Emails]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[Emails] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [TenantId] NVARCHAR(50) NOT NULL,
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
        [ProviderUsed] NVARCHAR(50) NULL,
        [Metadata] NVARCHAR(MAX) NULL,
        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [UpdatedAt] DATETIME2 NULL,

        INDEX IX_Emails_TenantId (TenantId),
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
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EmailAttachments]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[EmailAttachments] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [EmailId] INT NOT NULL,
        [FileName] NVARCHAR(255) NOT NULL,
        [ContentType] NVARCHAR(100) NOT NULL,
        [SizeInBytes] BIGINT NOT NULL,
        [Content] VARBINARY(MAX) NOT NULL,

        CONSTRAINT FK_EmailAttachments_Emails FOREIGN KEY (EmailId)
            REFERENCES Emails(Id) ON DELETE CASCADE,
        INDEX IX_EmailAttachments_EmailId (EmailId)
    );
END
GO

-- =============================================
-- Table: EmailTemplates
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EmailTemplates]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[EmailTemplates] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [TenantId] NVARCHAR(50) NOT NULL,
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

        INDEX IX_EmailTemplates_TenantId (TenantId),
        INDEX IX_EmailTemplates_IsActive (IsActive)
    );
END
GO

-- =============================================
-- Table: EmailCampaigns
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EmailCampaigns]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[EmailCampaigns] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [TenantId] NVARCHAR(50) NOT NULL,
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

        INDEX IX_EmailCampaigns_TenantId (TenantId),
        INDEX IX_EmailCampaigns_Status (Status),
        INDEX IX_EmailCampaigns_CreatedAt (CreatedAt)
    );
END
GO

-- =============================================
-- Table: CampaignRecipients
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CampaignRecipients]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[CampaignRecipients] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [CampaignId] INT NOT NULL,
        [EmailAddress] NVARCHAR(255) NOT NULL,
        [RecipientName] NVARCHAR(255) NULL,
        [PersonalizationData] NVARCHAR(MAX) NULL, -- JSON
        [EmailId] INT NULL,
        [Sent] BIT NOT NULL DEFAULT 0,
        [SentAt] DATETIME2 NULL,

        CONSTRAINT FK_CampaignRecipients_Campaigns FOREIGN KEY (CampaignId)
            REFERENCES EmailCampaigns(Id) ON DELETE CASCADE,
        INDEX IX_CampaignRecipients_CampaignId (CampaignId),
        INDEX IX_CampaignRecipients_Sent (Sent)
    );
END
GO

PRINT 'Database schema created successfully!';
GO
