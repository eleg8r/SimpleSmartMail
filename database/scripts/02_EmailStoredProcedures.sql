-- =============================================
-- Email Stored Procedures
-- =============================================

USE SimpleSmartMailDb;
GO

-- =============================================
-- sp_Email_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Email_Create]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Email_Create];
GO

CREATE PROCEDURE [emailCampaign].[sp_Email_Create]
    @FromAddress NVARCHAR(255),
    @FromName NVARCHAR(255),
    @ToAddress NVARCHAR(255),
    @ToName NVARCHAR(255),
    @Cc NVARCHAR(MAX) = NULL,
    @Bcc NVARCHAR(MAX) = NULL,
    @Subject NVARCHAR(500),
    @HtmlBody NVARCHAR(MAX),
    @TextBody NVARCHAR(MAX) = NULL,
    @Status INT,
    @CampaignId INT = NULL,
    @TrackingId UNIQUEIDENTIFIER,
    @OpenTracked BIT,
    @ClickTracked BIT,
    @ScheduledAt DATETIME2 = NULL,
    @IsValid BIT = 1,
    @ProviderUsed NVARCHAR(50) = NULL,
    @Metadata NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [emailCampaign].[Emails] (
        FromAddress, FromName, ToAddress, ToName,
        Cc, Bcc, Subject, HtmlBody, TextBody,
        Status, CampaignId, TrackingId, OpenTracked, ClickTracked,
        ScheduledAt, IsValid, ProviderUsed, Metadata, CreatedAt
    )
    VALUES (
        @FromAddress, @FromName, @ToAddress, @ToName,
        @Cc, @Bcc, @Subject, @HtmlBody, @TextBody,
        @Status, @CampaignId, @TrackingId, @OpenTracked, @ClickTracked,
        @ScheduledAt, @IsValid, @ProviderUsed, @Metadata, GETUTCDATE()
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS EmailId;
END
GO

-- =============================================
-- sp_Email_GetById
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Email_GetById]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Email_GetById];
GO

CREATE PROCEDURE [emailCampaign].[sp_Email_GetById]
    @EmailId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, FromAddress, FromName, ToAddress, ToName,
        Cc, Bcc, Subject, HtmlBody, TextBody,
        Status, CampaignId, TrackingId, OpenTracked, OpenedAt, OpenCount,
        ClickTracked, FirstClickedAt, ClickCount,
        ScheduledAt, SentAt, DeliveredAt,
        ErrorMessage, RetryCount, IsValid, ProviderUsed, Metadata,
        CreatedAt, UpdatedAt
    FROM [emailCampaign].[Emails]
    WHERE Id = @EmailId;
END
GO

-- =============================================
-- sp_Email_GetByTrackingId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Email_GetByTrackingId]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Email_GetByTrackingId];
GO

CREATE PROCEDURE [emailCampaign].[sp_Email_GetByTrackingId]
    @TrackingId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, FromAddress, FromName, ToAddress, ToName,
        Cc, Bcc, Subject, HtmlBody, TextBody,
        Status, CampaignId, TrackingId, OpenTracked, OpenedAt, OpenCount,
        ClickTracked, FirstClickedAt, ClickCount,
        ScheduledAt, SentAt, DeliveredAt,
        ErrorMessage, RetryCount, IsValid, ProviderUsed, Metadata,
        CreatedAt, UpdatedAt
    FROM [emailCampaign].[Emails]
    WHERE TrackingId = @TrackingId;
END
GO

-- =============================================
-- sp_Email_GetAll
-- Get all emails with pagination
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Email_GetAll]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Email_GetAll];
GO

CREATE PROCEDURE [emailCampaign].[sp_Email_GetAll]
    @PageNumber INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT
        Id, FromAddress, FromName, ToAddress, ToName,
        Cc, Bcc, Subject, HtmlBody, TextBody,
        Status, CampaignId, TrackingId, OpenTracked, OpenedAt, OpenCount,
        ClickTracked, FirstClickedAt, ClickCount,
        ScheduledAt, SentAt, DeliveredAt,
        ErrorMessage, RetryCount, IsValid, ProviderUsed, Metadata,
        CreatedAt, UpdatedAt
    FROM [emailCampaign].[Emails]
    ORDER BY CreatedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- =============================================
-- sp_Email_Update
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Email_Update]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Email_Update];
GO

CREATE PROCEDURE [emailCampaign].[sp_Email_Update]
    @EmailId INT,
    @Status INT,
    @OpenTracked BIT,
    @OpenedAt DATETIME2 = NULL,
    @OpenCount INT,
    @ClickTracked BIT,
    @FirstClickedAt DATETIME2 = NULL,
    @ClickCount INT,
    @SentAt DATETIME2 = NULL,
    @DeliveredAt DATETIME2 = NULL,
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @RetryCount INT,
    @IsValid BIT,
    @ProviderUsed NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [emailCampaign].[Emails]
    SET
        Status = @Status,
        OpenTracked = @OpenTracked,
        OpenedAt = @OpenedAt,
        OpenCount = @OpenCount,
        ClickTracked = @ClickTracked,
        FirstClickedAt = @FirstClickedAt,
        ClickCount = @ClickCount,
        SentAt = @SentAt,
        DeliveredAt = @DeliveredAt,
        ErrorMessage = @ErrorMessage,
        RetryCount = @RetryCount,
        IsValid = @IsValid,
        ProviderUsed = @ProviderUsed,
        UpdatedAt = GETUTCDATE()
    WHERE Id = @EmailId;
END
GO

-- =============================================
-- sp_Email_UpdateStatus
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Email_UpdateStatus]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Email_UpdateStatus];
GO

CREATE PROCEDURE [emailCampaign].[sp_Email_UpdateStatus]
    @EmailId INT,
    @Status INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [emailCampaign].[Emails]
    SET
        Status = @Status,
        UpdatedAt = GETUTCDATE()
    WHERE Id = @EmailId;
END
GO

-- =============================================
-- sp_EmailAttachment_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_EmailAttachment_Create]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_EmailAttachment_Create];
GO

CREATE PROCEDURE [emailCampaign].[sp_EmailAttachment_Create]
    @EmailId INT,
    @FileName NVARCHAR(255),
    @ContentType NVARCHAR(100),
    @SizeInBytes BIGINT,
    @Content VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [emailCampaign].[EmailAttachments] (EmailId, FileName, ContentType, SizeInBytes, Content)
    VALUES (@EmailId, @FileName, @ContentType, @SizeInBytes, @Content);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS AttachmentId;
END
GO

PRINT 'Email stored procedures created successfully!';
GO
