-- =============================================
-- Campaign Stored Procedures
-- =============================================

USE SimpleSmartMailDb;
GO

-- =============================================
-- Campaign_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Campaign_Create]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Campaign_Create];
GO

CREATE PROCEDURE [emailCampaign].[Campaign_Create]
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

    INSERT INTO [emailCampaign].[EmailCampaigns] (
        Name, Description, Status,
        FromAddress, FromName, Subject, HtmlTemplate, TextTemplate,
        ScheduledStartDate, BatchSize, MaxEmailsPerHour,
        EnableOpenTracking, EnableClickTracking, TotalRecipients,
        CreatedAt, CreatedBy
    )
    VALUES (
        @Name, @Description, @Status,
        @FromAddress, @FromName, @Subject, @HtmlTemplate, @TextTemplate,
        @ScheduledStartDate, @BatchSize, @MaxEmailsPerHour,
        @EnableOpenTracking, @EnableClickTracking, @TotalRecipients,
        GETUTCDATE(), @CreatedBy
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS CampaignId;
END
GO

-- =============================================
-- Campaign_GetById
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Campaign_GetById]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Campaign_GetById];
GO

CREATE PROCEDURE [emailCampaign].[Campaign_GetById]
    @CampaignId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, Name, Description, Status,
        FromAddress, FromName, Subject, HtmlTemplate, TextTemplate,
        ScheduledStartDate, BatchSize, MaxEmailsPerHour,
        EnableOpenTracking, EnableClickTracking,
        TotalRecipients, EmailsSent, EmailsDelivered,
        EmailsOpened, EmailsClicked, EmailsFailed,
        StartedAt, CompletedAt,
        CreatedAt, UpdatedAt, CreatedBy, UpdatedBy
    FROM [emailCampaign].[EmailCampaigns]
    WHERE Id = @CampaignId;
END
GO

-- =============================================
-- Campaign_GetAll
-- Get all campaigns with pagination
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Campaign_GetAll]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Campaign_GetAll];
GO

CREATE PROCEDURE [emailCampaign].[Campaign_GetAll]
    @PageNumber INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT
        Id, Name, Description, Status,
        FromAddress, FromName, Subject, HtmlTemplate, TextTemplate,
        ScheduledStartDate, BatchSize, MaxEmailsPerHour,
        EnableOpenTracking, EnableClickTracking,
        TotalRecipients, EmailsSent, EmailsDelivered,
        EmailsOpened, EmailsClicked, EmailsFailed,
        StartedAt, CompletedAt,
        CreatedAt, UpdatedAt, CreatedBy, UpdatedBy
    FROM [emailCampaign].[EmailCampaigns]
    ORDER BY CreatedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- =============================================
-- Campaign_Update
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Campaign_Update]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Campaign_Update];
GO

CREATE PROCEDURE [emailCampaign].[Campaign_Update]
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

    UPDATE [emailCampaign].[EmailCampaigns]
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
-- Campaign_UpdateStatistics
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Campaign_UpdateStatistics]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Campaign_UpdateStatistics];
GO

CREATE PROCEDURE [emailCampaign].[Campaign_UpdateStatistics]
    @CampaignId INT,
    @EmailsSent INT,
    @EmailsDelivered INT,
    @EmailsOpened INT,
    @EmailsClicked INT,
    @EmailsFailed INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [emailCampaign].[EmailCampaigns]
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
-- CampaignRecipient_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[CampaignRecipient_Create]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[CampaignRecipient_Create];
GO

CREATE PROCEDURE [emailCampaign].[CampaignRecipient_Create]
    @CampaignId INT,
    @EmailAddress NVARCHAR(255),
    @RecipientName NVARCHAR(255) = NULL,
    @PersonalizationData NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [emailCampaign].[CampaignRecipients] (CampaignId, EmailAddress, RecipientName, PersonalizationData)
    VALUES (@CampaignId, @EmailAddress, @RecipientName, @PersonalizationData);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS RecipientId;
END
GO

-- =============================================
-- CampaignRecipient_GetByCampaignId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[CampaignRecipient_GetByCampaignId]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[CampaignRecipient_GetByCampaignId];
GO

CREATE PROCEDURE [emailCampaign].[CampaignRecipient_GetByCampaignId]
    @CampaignId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, CampaignId, EmailAddress, RecipientName,
        PersonalizationData, EmailId, Sent, SentAt
    FROM [emailCampaign].[CampaignRecipients]
    WHERE CampaignId = @CampaignId
    ORDER BY Id;
END
GO

-- =============================================
-- CampaignRecipient_Update
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[CampaignRecipient_Update]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[CampaignRecipient_Update];
GO

CREATE PROCEDURE [emailCampaign].[CampaignRecipient_Update]
    @RecipientId INT,
    @EmailId INT = NULL,
    @Sent BIT,
    @SentAt DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [emailCampaign].[CampaignRecipients]
    SET
        EmailId = @EmailId,
        Sent = @Sent,
        SentAt = @SentAt
    WHERE Id = @RecipientId;
END
GO

-- =============================================
-- EmailCampaignPrograms Procedures
-- =============================================

-- EmailCampaignPrograms_AddProgram
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailCampaignPrograms_AddProgram]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[EmailCampaignPrograms_AddProgram];
GO

CREATE PROCEDURE [emailCampaign].[EmailCampaignPrograms_AddProgram]
    @EmailCampaignId INT,
    @ProgramId INT,
    @CreatedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if mapping already exists
    IF NOT EXISTS (
        SELECT 1 FROM [emailCampaign].[EmailCampaignPrograms]
        WHERE EmailCampaignId = @EmailCampaignId AND ProgramId = @ProgramId
    )
    BEGIN
        INSERT INTO [emailCampaign].[EmailCampaignPrograms] (
            EmailCampaignId, ProgramId, CreatedAtUtc, CreatedBy
        )
        VALUES (
            @EmailCampaignId, @ProgramId, GETUTCDATE(), @CreatedBy
        );
    END

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

-- EmailCampaignPrograms_RemoveProgram
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailCampaignPrograms_RemoveProgram]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[EmailCampaignPrograms_RemoveProgram];
GO

CREATE PROCEDURE [emailCampaign].[EmailCampaignPrograms_RemoveProgram]
    @EmailCampaignId INT,
    @ProgramId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM [emailCampaign].[EmailCampaignPrograms]
    WHERE EmailCampaignId = @EmailCampaignId AND ProgramId = @ProgramId;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

-- EmailCampaignPrograms_GetByCampaignId
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailCampaignPrograms_GetByCampaignId]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[EmailCampaignPrograms_GetByCampaignId];
GO

CREATE PROCEDURE [emailCampaign].[EmailCampaignPrograms_GetByCampaignId]
    @EmailCampaignId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        EmailCampaignId, ProgramId, CreatedAtUtc, UpdatedAtUtc, CreatedBy, UpdatedBy
    FROM [emailCampaign].[EmailCampaignPrograms]
    WHERE EmailCampaignId = @EmailCampaignId
    ORDER BY CreatedAtUtc;
END
GO

-- EmailCampaignPrograms_GetByProgramId
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailCampaignPrograms_GetByProgramId]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[EmailCampaignPrograms_GetByProgramId];
GO

CREATE PROCEDURE [emailCampaign].[EmailCampaignPrograms_GetByProgramId]
    @ProgramId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.Id, c.Name, c.Description, c.Status,
        c.FromAddress, c.FromName, c.Subject,
        c.TotalRecipients, c.EmailsSent, c.EmailsDelivered,
        c.EmailsOpened, c.EmailsClicked, c.EmailsFailed,
        c.StartedAt, c.CompletedAt,
        c.CreatedAt, c.UpdatedAt, c.CreatedBy, c.UpdatedBy
    FROM [emailCampaign].[EmailCampaigns] c
    INNER JOIN [emailCampaign].[EmailCampaignPrograms] ecp ON c.Id = ecp.EmailCampaignId
    WHERE ecp.ProgramId = @ProgramId
    ORDER BY c.CreatedAt DESC;
END
GO

PRINT 'Campaign stored procedures created successfully!';
GO
