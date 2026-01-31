-- =============================================
-- Survey Tracking Tables and Procedures
-- =============================================

USE SimpleSmartMailDb;
GO

-- =============================================
-- SurveyResponses Table
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[SurveyResponses]') AND type = 'U')
BEGIN
    CREATE TABLE [emailCampaign].[SurveyResponses] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [EmailId] INT NOT NULL,
        [CampaignId] INT NULL,
        [TrackingId] UNIQUEIDENTIFIER NOT NULL,
        [RecipientEmail] NVARCHAR(255) NOT NULL,
        [QuestionId] NVARCHAR(100) NOT NULL,
        [AnswerId] NVARCHAR(100) NOT NULL,
        [AnswerText] NVARCHAR(MAX) NULL,
        [RespondedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [IpAddress] NVARCHAR(50) NULL,
        [UserAgent] NVARCHAR(MAX) NULL,

        CONSTRAINT FK_SurveyResponses_Emails FOREIGN KEY (EmailId)
            REFERENCES [emailCampaign].[Emails](Id) ON DELETE CASCADE,
        INDEX IX_SurveyResponses_EmailId (EmailId),
        INDEX IX_SurveyResponses_CampaignId (CampaignId),
        INDEX IX_SurveyResponses_TrackingId (TrackingId),
        INDEX IX_SurveyResponses_QuestionId (QuestionId),
        INDEX IX_SurveyResponses_AnswerId (AnswerId)
    );

    PRINT 'SurveyResponses table created successfully!';
END
ELSE
BEGIN
    PRINT 'SurveyResponses table already exists, skipping creation.';
END
GO

-- =============================================
-- Survey_RecordResponse
-- Looks up email by trackingId internally
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Survey_RecordResponse]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Survey_RecordResponse];
GO

CREATE PROCEDURE [emailCampaign].[Survey_RecordResponse]
    @TrackingId UNIQUEIDENTIFIER,
    @QuestionId NVARCHAR(100),
    @AnswerId NVARCHAR(100),
    @AnswerText NVARCHAR(MAX) = NULL,
    @IpAddress NVARCHAR(50) = NULL,
    @UserAgent NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Look up email by tracking ID
    DECLARE @EmailId INT;
    DECLARE @CampaignId INT;
    DECLARE @RecipientEmail NVARCHAR(255);

    SELECT
        @EmailId = Id,
        @CampaignId = CampaignId,
        @RecipientEmail = ToAddress
    FROM [emailCampaign].[Emails]
    WHERE TrackingId = @TrackingId;

    -- If email not found, raise error
    IF @EmailId IS NULL
    BEGIN
        RAISERROR('Email not found for tracking ID', 16, 1);
        RETURN;
    END

    -- Insert survey response
    INSERT INTO [emailCampaign].[SurveyResponses] (
        EmailId, CampaignId, TrackingId, RecipientEmail,
        QuestionId, AnswerId, AnswerText,
        RespondedAt, IpAddress, UserAgent
    )
    VALUES (
        @EmailId, @CampaignId, @TrackingId, @RecipientEmail,
        @QuestionId, @AnswerId, @AnswerText,
        GETUTCDATE(), @IpAddress, @UserAgent
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS ResponseId;
END
GO

-- =============================================
-- Survey_GetResponsesByEmail
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Survey_GetResponsesByEmail]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Survey_GetResponsesByEmail];
GO

CREATE PROCEDURE [emailCampaign].[Survey_GetResponsesByEmail]
    @EmailId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, EmailId, CampaignId, TrackingId,
        RecipientEmail, QuestionId, AnswerId, AnswerText,
        RespondedAt, IpAddress, UserAgent
    FROM [emailCampaign].[SurveyResponses]
    WHERE EmailId = @EmailId
    ORDER BY RespondedAt DESC;
END
GO

-- =============================================
-- Survey_GetResponsesByCampaign
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[Survey_GetResponsesByCampaign]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[Survey_GetResponsesByCampaign];
GO

CREATE PROCEDURE [emailCampaign].[Survey_GetResponsesByCampaign]
    @CampaignId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, EmailId, CampaignId, TrackingId,
        RecipientEmail, QuestionId, AnswerId, AnswerText,
        RespondedAt, IpAddress, UserAgent
    FROM [emailCampaign].[SurveyResponses]
    WHERE CampaignId = @CampaignId
    ORDER BY RespondedAt DESC;
END
GO

PRINT 'Survey stored procedures created successfully!';
GO
