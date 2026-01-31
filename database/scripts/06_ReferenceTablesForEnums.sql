-- =============================================
-- Reference Tables for Enums
-- =============================================

USE SimpleSmartMailDb;
GO

-- =============================================
-- Ref_EmailStatuses
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Ref_EmailStatuses]') AND type = 'U')
BEGIN
    CREATE TABLE [emailCampaign].[Ref_EmailStatuses] (
        StatusId INT PRIMARY KEY,
        StatusName NVARCHAR(50) NOT NULL,
        StatusDescription NVARCHAR(MAX) NULL
    );

    INSERT INTO [emailCampaign].[Ref_EmailStatuses] (StatusId, StatusName, StatusDescription)
    VALUES
        (0, 'Queued', 'Email is queued for sending'),
        (1, 'Processing', 'Email is currently being processed'),
        (2, 'Sent', 'Email has been sent to the provider'),
        (3, 'Accepted', 'Email accepted by the receiving server'),
        (4, 'Delivered', 'Email successfully delivered to recipient'),
        (5, 'Opened', 'Recipient opened the email'),
        (6, 'Clicked', 'Recipient clicked a link in the email'),
        (7, 'Bounced', 'Email bounced back'),
        (8, 'Failed', 'Email failed to send'),
        (9, 'SpamComplaint', 'Recipient marked email as spam'),
        (10, 'Unsubscribed', 'Recipient unsubscribed');

    PRINT 'Ref_EmailStatuses table created and populated successfully!';
END
ELSE
BEGIN
    PRINT 'Ref_EmailStatuses table already exists, skipping creation.';
END
GO

-- =============================================
-- Ref_CampaignStatuses
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Ref_CampaignStatuses]') AND type = 'U')
BEGIN
    CREATE TABLE [emailCampaign].[Ref_CampaignStatuses] (
        StatusId INT PRIMARY KEY,
        StatusName NVARCHAR(50) NOT NULL,
        StatusDescription NVARCHAR(MAX) NULL
    );

    INSERT INTO [emailCampaign].[Ref_CampaignStatuses] (StatusId, StatusName, StatusDescription)
    VALUES
        (0, 'Draft', 'Campaign is in draft state'),
        (1, 'Scheduled', 'Campaign is scheduled to run'),
        (2, 'InProgress', 'Campaign is currently running'),
        (3, 'Paused', 'Campaign has been paused'),
        (4, 'Completed', 'Campaign completed successfully'),
        (5, 'Cancelled', 'Campaign was cancelled'),
        (6, 'Failed', 'Campaign failed to execute');

    PRINT 'Ref_CampaignStatuses table created and populated successfully!';
END
ELSE
BEGIN
    PRINT 'Ref_CampaignStatuses table already exists, skipping creation.';
END
GO

-- =============================================
-- Ref_EmailProviderTypes
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Ref_EmailProviderTypes]') AND type = 'U')
BEGIN
    CREATE TABLE [emailCampaign].[Ref_EmailProviderTypes] (
        ProviderTypeId INT PRIMARY KEY,
        ProviderTypeName NVARCHAR(50) NOT NULL,
        ProviderTypeDescription NVARCHAR(MAX) NULL
    );

    INSERT INTO [emailCampaign].[Ref_EmailProviderTypes] (ProviderTypeId, ProviderTypeName, ProviderTypeDescription)
    VALUES
        (0, 'Smtp', 'Standard SMTP email provider'),
        (1, 'SendGrid', 'SendGrid email service provider');

    PRINT 'Ref_EmailProviderTypes table created and populated successfully!';
END
ELSE
BEGIN
    PRINT 'Ref_EmailProviderTypes table already exists, skipping creation.';
END
GO

PRINT 'All reference tables for enums have been processed!';
GO
