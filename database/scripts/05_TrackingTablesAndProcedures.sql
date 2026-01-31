-- =============================================
-- Tracking Stored Procedures
-- =============================================

USE SimpleSmartMailDb;
GO

-- =============================================
-- Tracking_RecordOpen
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Tracking_RecordOpen]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Tracking_RecordOpen];
GO

CREATE PROCEDURE [emailCampaign].[Tracking_RecordOpen]
    @TrackingId UNIQUEIDENTIFIER,
    @IpAddress NVARCHAR(50) = NULL,
    @UserAgent NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Update the email record
    UPDATE [emailCampaign].[Emails]
    SET
        OpenTracked = 1,
        OpenedAt = CASE WHEN OpenedAt IS NULL THEN GETUTCDATE() ELSE OpenedAt END,
        OpenCount = OpenCount + 1,
        Status = CASE WHEN Status < 5 THEN 5 ELSE Status END, -- 5 = Opened
        UpdatedAt = GETUTCDATE()
    WHERE TrackingId = @TrackingId;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

-- =============================================
-- Tracking_RecordClick
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Tracking_RecordClick]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Tracking_RecordClick];
GO

CREATE PROCEDURE [emailCampaign].[Tracking_RecordClick]
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

    INSERT INTO [emailCampaign].[EmailClicks] (
        EmailId, CampaignId, TrackingId,
        RecipientEmail, OriginalUrl, TrackedUrl,
        ClickedAt, IpAddress, UserAgent,
        Country, City, Device
    )
    VALUES (
        @EmailId, @CampaignId, @TrackingId,
        @RecipientEmail, @OriginalUrl, @TrackedUrl,
        GETUTCDATE(), @IpAddress, @UserAgent,
        @Country, @City, @Device
    );

    -- Update email click tracking
    UPDATE [emailCampaign].[Emails]
    SET
        ClickTracked = 1,
        FirstClickedAt = CASE WHEN FirstClickedAt IS NULL THEN GETUTCDATE() ELSE FirstClickedAt END,
        ClickCount = ClickCount + 1,
        Status = CASE WHEN Status < 6 THEN 6 ELSE Status END, -- 6 = Clicked
        UpdatedAt = GETUTCDATE()
    WHERE Id = @EmailId;

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS ClickId;
END
GO

-- =============================================
-- Tracking_GetClicksByEmailId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Tracking_GetClicksByEmailId]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Tracking_GetClicksByEmailId];
GO

CREATE PROCEDURE [emailCampaign].[Tracking_GetClicksByEmailId]
    @EmailId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, EmailId, CampaignId, TrackingId,
        RecipientEmail, OriginalUrl, TrackedUrl,
        ClickedAt, IpAddress, UserAgent,
        Country, City, Device
    FROM [emailCampaign].[EmailClicks]
    WHERE EmailId = @EmailId
    ORDER BY ClickedAt DESC;
END
GO

-- =============================================
-- Tracking_GetClicksByCampaignId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Tracking_GetClicksByCampaignId]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Tracking_GetClicksByCampaignId];
GO

CREATE PROCEDURE [emailCampaign].[Tracking_GetClicksByCampaignId]
    @CampaignId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, EmailId, CampaignId, TrackingId,
        RecipientEmail, OriginalUrl, TrackedUrl,
        ClickedAt, IpAddress, UserAgent,
        Country, City, Device
    FROM [emailCampaign].[EmailClicks]
    WHERE CampaignId = @CampaignId
    ORDER BY ClickedAt DESC;
END
GO

-- =============================================
-- Unsubscribe Procedures
-- =============================================

-- Unsubscribe_Create
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Unsubscribe_Create]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Unsubscribe_Create];
GO

CREATE PROCEDURE [emailCampaign].[Unsubscribe_Create]
    @EmailAddress NVARCHAR(255),
    @ProgramId INT = NULL, -- NULL = global unsubscribe
    @CampaignId INT = NULL,
    @EmailId INT = NULL,
    @TrackingId UNIQUEIDENTIFIER = NULL,
    @Reason NVARCHAR(MAX) = NULL,
    @IpAddress NVARCHAR(50) = NULL,
    @UserAgent NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [emailCampaign].[UnsubscribeRequests] (
        EmailAddress, ProgramId, CampaignId, EmailId, TrackingId,
        UnsubscribedAt, Reason, IpAddress, UserAgent
    )
    VALUES (
        @EmailAddress, @ProgramId, @CampaignId, @EmailId, @TrackingId,
        GETUTCDATE(), @Reason, @IpAddress, @UserAgent
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS RequestId;
END
GO

-- Unsubscribe_IsUnsubscribed
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Unsubscribe_IsUnsubscribed]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Unsubscribe_IsUnsubscribed];
GO

CREATE PROCEDURE [emailCampaign].[Unsubscribe_IsUnsubscribed]
    @EmailAddress NVARCHAR(255),
    @ProgramId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Returns 1 if unsubscribed globally (ProgramId IS NULL)
    -- OR from specific program (ProgramId = @ProgramId)
    SELECT CASE
        WHEN EXISTS (
            SELECT 1 FROM [emailCampaign].[UnsubscribeRequests]
            WHERE EmailAddress = @EmailAddress
              AND (ProgramId IS NULL OR ProgramId = @ProgramId)
        ) THEN CAST(1 AS BIT)
        ELSE CAST(0 AS BIT)
    END AS IsUnsubscribed;
END
GO

-- Unsubscribe_GetByProgramId
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Unsubscribe_GetByProgramId]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Unsubscribe_GetByProgramId];
GO

CREATE PROCEDURE [emailCampaign].[Unsubscribe_GetByProgramId]
    @ProgramId INT = NULL -- NULL = get global unsubscribes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, EmailAddress, ProgramId, CampaignId, EmailId, TrackingId,
        UnsubscribedAt, Reason, IpAddress, UserAgent
    FROM [emailCampaign].[UnsubscribeRequests]
    WHERE (@ProgramId IS NULL AND ProgramId IS NULL)
       OR (ProgramId = @ProgramId)
    ORDER BY UnsubscribedAt DESC;
END
GO

-- Unsubscribe_GetAll
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Unsubscribe_GetAll]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Unsubscribe_GetAll];
GO

CREATE PROCEDURE [emailCampaign].[Unsubscribe_GetAll]
    @PageNumber INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT
        Id, EmailAddress, ProgramId, CampaignId, EmailId, TrackingId,
        UnsubscribedAt, Reason, IpAddress, UserAgent
    FROM [emailCampaign].[UnsubscribeRequests]
    ORDER BY UnsubscribedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT 'Tracking stored procedures created successfully!';
GO
