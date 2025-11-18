-- =============================================
-- Email Stored Procedures
-- =============================================

USE SimpleSmartMailDb;
GO

-- =============================================
-- sp_Email_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Email_Create]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Email_Create];
GO

CREATE PROCEDURE [dbo].[sp_Email_Create]
    @TenantId NVARCHAR(50),
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
    @ProviderUsed NVARCHAR(50) = NULL,
    @Metadata NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Emails (
        TenantId, FromAddress, FromName, ToAddress, ToName,
        Cc, Bcc, Subject, HtmlBody, TextBody,
        Status, CampaignId, TrackingId, OpenTracked, ClickTracked,
        ScheduledAt, ProviderUsed, Metadata, CreatedAt
    )
    VALUES (
        @TenantId, @FromAddress, @FromName, @ToAddress, @ToName,
        @Cc, @Bcc, @Subject, @HtmlBody, @TextBody,
        @Status, @CampaignId, @TrackingId, @OpenTracked, @ClickTracked,
        @ScheduledAt, @ProviderUsed, @Metadata, GETUTCDATE()
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS EmailId;
END
GO

-- =============================================
-- sp_Email_GetById
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Email_GetById]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Email_GetById];
GO

CREATE PROCEDURE [dbo].[sp_Email_GetById]
    @EmailId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, FromAddress, FromName, ToAddress, ToName,
        Cc, Bcc, Subject, HtmlBody, TextBody,
        Status, CampaignId, TrackingId, OpenTracked, OpenedAt, OpenCount,
        ClickTracked, FirstClickedAt, ClickCount,
        ScheduledAt, SentAt, DeliveredAt,
        ErrorMessage, RetryCount, ProviderUsed, Metadata,
        CreatedAt, UpdatedAt
    FROM Emails
    WHERE Id = @EmailId;
END
GO

-- =============================================
-- sp_Email_GetByTrackingId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Email_GetByTrackingId]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Email_GetByTrackingId];
GO

CREATE PROCEDURE [dbo].[sp_Email_GetByTrackingId]
    @TrackingId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, FromAddress, FromName, ToAddress, ToName,
        Cc, Bcc, Subject, HtmlBody, TextBody,
        Status, CampaignId, TrackingId, OpenTracked, OpenedAt, OpenCount,
        ClickTracked, FirstClickedAt, ClickCount,
        ScheduledAt, SentAt, DeliveredAt,
        ErrorMessage, RetryCount, ProviderUsed, Metadata,
        CreatedAt, UpdatedAt
    FROM Emails
    WHERE TrackingId = @TrackingId;
END
GO

-- =============================================
-- sp_Email_GetByTenantId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Email_GetByTenantId]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Email_GetByTenantId];
GO

CREATE PROCEDURE [dbo].[sp_Email_GetByTenantId]
    @TenantId NVARCHAR(50),
    @PageNumber INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT
        Id, TenantId, FromAddress, FromName, ToAddress, ToName,
        Cc, Bcc, Subject, HtmlBody, TextBody,
        Status, CampaignId, TrackingId, OpenTracked, OpenedAt, OpenCount,
        ClickTracked, FirstClickedAt, ClickCount,
        ScheduledAt, SentAt, DeliveredAt,
        ErrorMessage, RetryCount, ProviderUsed, Metadata,
        CreatedAt, UpdatedAt
    FROM Emails
    WHERE TenantId = @TenantId
    ORDER BY CreatedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- =============================================
-- sp_Email_Update
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Email_Update]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Email_Update];
GO

CREATE PROCEDURE [dbo].[sp_Email_Update]
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
    @ProviderUsed NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Emails
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
        ProviderUsed = @ProviderUsed,
        UpdatedAt = GETUTCDATE()
    WHERE Id = @EmailId;
END
GO

-- =============================================
-- sp_Email_UpdateStatus
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Email_UpdateStatus]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Email_UpdateStatus];
GO

CREATE PROCEDURE [dbo].[sp_Email_UpdateStatus]
    @EmailId INT,
    @Status INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Emails
    SET
        Status = @Status,
        UpdatedAt = GETUTCDATE()
    WHERE Id = @EmailId;
END
GO

-- =============================================
-- sp_EmailAttachment_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_EmailAttachment_Create]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_EmailAttachment_Create];
GO

CREATE PROCEDURE [dbo].[sp_EmailAttachment_Create]
    @EmailId INT,
    @FileName NVARCHAR(255),
    @ContentType NVARCHAR(100),
    @SizeInBytes BIGINT,
    @Content VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO EmailAttachments (EmailId, FileName, ContentType, SizeInBytes, Content)
    VALUES (@EmailId, @FileName, @ContentType, @SizeInBytes, @Content);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS AttachmentId;
END
GO

PRINT 'Email stored procedures created successfully!';
GO
