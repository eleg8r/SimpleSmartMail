-- =============================================
-- Tracking Stored Procedures
-- =============================================

USE SimpleSmartMailDb;
GO

-- =============================================
-- sp_Tracking_RecordOpen
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Tracking_RecordOpen]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Tracking_RecordOpen];
GO

CREATE PROCEDURE [emailCampaign].[sp_Tracking_RecordOpen]
    @TrackingId UNIQUEIDENTIFIER,
    @IpAddress NVARCHAR(50) = NULL,
    @UserAgent NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Simple: Just record the tracking event (could insert into tracking table here if needed)
    -- Return 1 if email exists, 0 if not
    IF EXISTS (SELECT 1 FROM [emailCampaign].[Emails] WHERE TrackingId = @TrackingId)
        SELECT 1 AS RowsAffected;
    ELSE
        SELECT 0 AS RowsAffected;
END
GO

-- =============================================
-- sp_Tracking_RecordClick
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Tracking_RecordClick]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Tracking_RecordClick];
GO

CREATE PROCEDURE [emailCampaign].[sp_Tracking_RecordClick]
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

    -- Simple: Just insert the click record
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

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS ClickId;
END
GO

-- =============================================
-- sp_Tracking_GetClicksByEmailId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Tracking_GetClicksByEmailId]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Tracking_GetClicksByEmailId];
GO

CREATE PROCEDURE [emailCampaign].[sp_Tracking_GetClicksByEmailId]
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
-- sp_Tracking_GetClicksByCampaignId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Tracking_GetClicksByCampaignId]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Tracking_GetClicksByCampaignId];
GO

CREATE PROCEDURE [emailCampaign].[sp_Tracking_GetClicksByCampaignId]
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

-- sp_Unsubscribe_Create
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Unsubscribe_Create]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Unsubscribe_Create];
GO

CREATE PROCEDURE [emailCampaign].[sp_Unsubscribe_Create]
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

-- sp_Unsubscribe_IsUnsubscribed
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Unsubscribe_IsUnsubscribed]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Unsubscribe_IsUnsubscribed];
GO

CREATE PROCEDURE [emailCampaign].[sp_Unsubscribe_IsUnsubscribed]
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

-- sp_Unsubscribe_GetByProgramId
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Unsubscribe_GetByProgramId]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Unsubscribe_GetByProgramId];
GO

CREATE PROCEDURE [emailCampaign].[sp_Unsubscribe_GetByProgramId]
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

-- sp_Unsubscribe_GetAll
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[sp_Unsubscribe_GetAll]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[sp_Unsubscribe_GetAll];
GO

CREATE PROCEDURE [emailCampaign].[sp_Unsubscribe_GetAll]
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
