-- =============================================
-- Campaign Stored Procedures
-- =============================================

USE SimpleSmartMailDb;
GO

-- =============================================
-- sp_Campaign_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Campaign_Create]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Campaign_Create];
GO

CREATE PROCEDURE [dbo].[sp_Campaign_Create]
    @TenantId NVARCHAR(50),
    @Name NVARCHAR(255),
    @Description NVARCHAR(1000),
    @Status INT,
    @FromAddress NVARCHAR(255),
    @FromName NVARCHAR(255),
    @Subject NVARCHAR(500),
    @HtmlTemplate NVARCHAR(MAX),
    @TextTemplate NVARCHAR(MAX) = NULL,
    @ScheduledStartDate DATETIME2 = NULL,
    @BatchSize INT = NULL,
    @MaxEmailsPerHour INT = NULL,
    @EnableOpenTracking BIT,
    @EnableClickTracking BIT,
    @TotalRecipients INT,
    @CreatedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO EmailCampaigns (
        TenantId, Name, Description, Status,
        FromAddress, FromName, Subject, HtmlTemplate, TextTemplate,
        ScheduledStartDate, BatchSize, MaxEmailsPerHour,
        EnableOpenTracking, EnableClickTracking, TotalRecipients,
        CreatedAt, CreatedBy
    )
    VALUES (
        @TenantId, @Name, @Description, @Status,
        @FromAddress, @FromName, @Subject, @HtmlTemplate, @TextTemplate,
        @ScheduledStartDate, @BatchSize, @MaxEmailsPerHour,
        @EnableOpenTracking, @EnableClickTracking, @TotalRecipients,
        GETUTCDATE(), @CreatedBy
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS CampaignId;
END
GO

-- =============================================
-- sp_Campaign_GetById
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Campaign_GetById]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Campaign_GetById];
GO

CREATE PROCEDURE [dbo].[sp_Campaign_GetById]
    @CampaignId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, Name, Description, Status,
        FromAddress, FromName, Subject, HtmlTemplate, TextTemplate,
        ScheduledStartDate, BatchSize, MaxEmailsPerHour,
        EnableOpenTracking, EnableClickTracking,
        TotalRecipients, EmailsSent, EmailsDelivered,
        EmailsOpened, EmailsClicked, EmailsFailed,
        StartedAt, CompletedAt,
        CreatedAt, UpdatedAt, CreatedBy, UpdatedBy
    FROM EmailCampaigns
    WHERE Id = @CampaignId;
END
GO

-- =============================================
-- sp_Campaign_GetByTenantId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Campaign_GetByTenantId]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Campaign_GetByTenantId];
GO

CREATE PROCEDURE [dbo].[sp_Campaign_GetByTenantId]
    @TenantId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, Name, Description, Status,
        FromAddress, FromName, Subject, HtmlTemplate, TextTemplate,
        ScheduledStartDate, BatchSize, MaxEmailsPerHour,
        EnableOpenTracking, EnableClickTracking,
        TotalRecipients, EmailsSent, EmailsDelivered,
        EmailsOpened, EmailsClicked, EmailsFailed,
        StartedAt, CompletedAt,
        CreatedAt, UpdatedAt, CreatedBy, UpdatedBy
    FROM EmailCampaigns
    WHERE TenantId = @TenantId
    ORDER BY CreatedAt DESC;
END
GO

-- =============================================
-- sp_Campaign_Update
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Campaign_Update]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Campaign_Update];
GO

CREATE PROCEDURE [dbo].[sp_Campaign_Update]
    @CampaignId INT,
    @Name NVARCHAR(255),
    @Description NVARCHAR(1000),
    @Status INT,
    @ScheduledStartDate DATETIME2 = NULL,
    @StartedAt DATETIME2 = NULL,
    @CompletedAt DATETIME2 = NULL,
    @UpdatedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE EmailCampaigns
    SET
        Name = @Name,
        Description = @Description,
        Status = @Status,
        ScheduledStartDate = @ScheduledStartDate,
        StartedAt = @StartedAt,
        CompletedAt = @CompletedAt,
        UpdatedAt = GETUTCDATE(),
        UpdatedBy = @UpdatedBy
    WHERE Id = @CampaignId;
END
GO

-- =============================================
-- sp_Campaign_UpdateStatistics
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Campaign_UpdateStatistics]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_Campaign_UpdateStatistics];
GO

CREATE PROCEDURE [dbo].[sp_Campaign_UpdateStatistics]
    @CampaignId INT,
    @EmailsSent INT,
    @EmailsDelivered INT,
    @EmailsOpened INT,
    @EmailsClicked INT,
    @EmailsFailed INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE EmailCampaigns
    SET
        EmailsSent = EmailsSent + @EmailsSent,
        EmailsDelivered = EmailsDelivered + @EmailsDelivered,
        EmailsOpened = EmailsOpened + @EmailsOpened,
        EmailsClicked = EmailsClicked + @EmailsClicked,
        EmailsFailed = EmailsFailed + @EmailsFailed,
        UpdatedAt = GETUTCDATE()
    WHERE Id = @CampaignId;
END
GO

-- =============================================
-- sp_CampaignRecipient_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_CampaignRecipient_Create]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_CampaignRecipient_Create];
GO

CREATE PROCEDURE [dbo].[sp_CampaignRecipient_Create]
    @CampaignId INT,
    @EmailAddress NVARCHAR(255),
    @RecipientName NVARCHAR(255) = NULL,
    @PersonalizationData NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO CampaignRecipients (CampaignId, EmailAddress, RecipientName, PersonalizationData)
    VALUES (@CampaignId, @EmailAddress, @RecipientName, @PersonalizationData);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS RecipientId;
END
GO

-- =============================================
-- sp_CampaignRecipient_GetByCampaignId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_CampaignRecipient_GetByCampaignId]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_CampaignRecipient_GetByCampaignId];
GO

CREATE PROCEDURE [dbo].[sp_CampaignRecipient_GetByCampaignId]
    @CampaignId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, CampaignId, EmailAddress, RecipientName,
        PersonalizationData, EmailId, Sent, SentAt
    FROM CampaignRecipients
    WHERE CampaignId = @CampaignId
    ORDER BY Id;
END
GO

-- =============================================
-- sp_CampaignRecipient_Update
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_CampaignRecipient_Update]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_CampaignRecipient_Update];
GO

CREATE PROCEDURE [dbo].[sp_CampaignRecipient_Update]
    @RecipientId INT,
    @EmailId INT = NULL,
    @Sent BIT,
    @SentAt DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE CampaignRecipients
    SET
        EmailId = @EmailId,
        Sent = @Sent,
        SentAt = @SentAt
    WHERE Id = @RecipientId;
END
GO

PRINT 'Campaign stored procedures created successfully!';
GO
