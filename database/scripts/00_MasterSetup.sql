-- =============================================
-- SimpleSmartMail Database - Master Setup Script
-- Run this script to create the complete database
-- =============================================
-- SQL Server 2019+
-- Execution Order: This script runs all setup scripts in the correct order
-- =============================================

PRINT '========================================';
PRINT 'SimpleSmartMail Database Setup';
PRINT 'Starting at: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '========================================';
GO

-- =============================================
-- STEP 1: Create Database and Schema
-- =============================================
PRINT '';
PRINT 'STEP 1: Creating database and tables...';
GO

USE master;
GO

-- Create database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SimpleSmartMailDb')
BEGIN
    CREATE DATABASE SimpleSmartMailDb;
    PRINT 'Database SimpleSmartMailDb created.';
END
ELSE
BEGIN
    PRINT 'Database SimpleSmartMailDb already exists.';
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
        [Status] INT NOT NULL DEFAULT 0,
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
    PRINT 'Table Emails created.';
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
    PRINT 'Table EmailAttachments created.';
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
    PRINT 'Table EmailTemplates created.';
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
        [Status] INT NOT NULL DEFAULT 0,
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
    PRINT 'Table EmailCampaigns created.';
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
        [PersonalizationData] NVARCHAR(MAX) NULL,
        [EmailId] INT NULL,
        [Sent] BIT NOT NULL DEFAULT 0,
        [SentAt] DATETIME2 NULL,

        CONSTRAINT FK_CampaignRecipients_Campaigns FOREIGN KEY (CampaignId)
            REFERENCES EmailCampaigns(Id) ON DELETE CASCADE,
        INDEX IX_CampaignRecipients_CampaignId (CampaignId),
        INDEX IX_CampaignRecipients_Sent (Sent)
    );
    PRINT 'Table CampaignRecipients created.';
END
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
    PRINT 'Table Tenants created.';
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
    PRINT 'Table EmailClicks created.';
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
    PRINT 'Table UnsubscribeRequests created.';
END
GO

PRINT 'Database schema created successfully!';
PRINT '';
GO

-- Continue to stored procedures...
-- (Due to length, stored procedures are in separate files)
-- Run the following scripts in order:
-- 1. This file (00_MasterSetup.sql)
-- 2. 02_EmailStoredProcedures.sql
-- 3. 03_EmailTemplateStoredProcedures.sql
-- 4. 04_CampaignStoredProcedures.sql
-- 5. 05_TrackingTablesAndProcedures.sql (procedures only, tables already created above)

PRINT '========================================';
PRINT 'Master setup complete!';
PRINT 'Next: Run stored procedure scripts 02-05';
PRINT 'Finished at: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '========================================';
GO
