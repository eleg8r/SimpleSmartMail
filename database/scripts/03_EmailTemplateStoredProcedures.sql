-- =============================================
-- Email Template Stored Procedures
-- =============================================

USE SimpleSmartMailDb;
GO

-- =============================================
-- EmailTemplate_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailTemplate_Create]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[EmailTemplate_Create];
GO

CREATE PROCEDURE [emailCampaign].[EmailTemplate_Create]
    @Name NVARCHAR(255),
    @Description NVARCHAR(1000),
    @Subject NVARCHAR(500),
    @HtmlTemplate NVARCHAR(MAX),
    @TextTemplate NVARCHAR(MAX) = NULL,
    @IsActive BIT,
    @CreatedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [emailCampaign].[EmailTemplates] (
        Name, Description, Subject,
        HtmlTemplate, TextTemplate, IsActive,
        CreatedAt, CreatedBy
    )
    VALUES (
        @Name, @Description, @Subject,
        @HtmlTemplate, @TextTemplate, @IsActive,
        GETUTCDATE(), @CreatedBy
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS TemplateId;
END
GO

-- =============================================
-- EmailTemplate_GetById
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailTemplate_GetById]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[EmailTemplate_GetById];
GO

CREATE PROCEDURE [emailCampaign].[EmailTemplate_GetById]
    @TemplateId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, Name, Description, Subject,
        HtmlTemplate, TextTemplate, IsActive,
        CreatedAt, UpdatedAt, CreatedBy, UpdatedBy
    FROM [emailCampaign].[EmailTemplates]
    WHERE Id = @TemplateId;
END
GO

-- =============================================
-- EmailTemplate_GetAll
-- Get all templates with optional active filter
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailTemplate_GetAll]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[EmailTemplate_GetAll];
GO

CREATE PROCEDURE [emailCampaign].[EmailTemplate_GetAll]
    @ActiveOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, Name, Description, Subject,
        HtmlTemplate, TextTemplate, IsActive,
        CreatedAt, UpdatedAt, CreatedBy, UpdatedBy
    FROM [emailCampaign].[EmailTemplates]
    WHERE @ActiveOnly = 0 OR IsActive = 1
    ORDER BY CreatedAt DESC;
END
GO

-- =============================================
-- EmailTemplate_Update
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailTemplate_Update]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[EmailTemplate_Update];
GO

CREATE PROCEDURE [emailCampaign].[EmailTemplate_Update]
    @TemplateId INT,
    @Name NVARCHAR(255),
    @Description NVARCHAR(1000),
    @Subject NVARCHAR(500),
    @HtmlTemplate NVARCHAR(MAX),
    @TextTemplate NVARCHAR(MAX) = NULL,
    @IsActive BIT,
    @UpdatedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [emailCampaign].[EmailTemplates]
    SET
        Name = @Name,
        Description = @Description,
        Subject = @Subject,
        HtmlTemplate = @HtmlTemplate,
        TextTemplate = @TextTemplate,
        IsActive = @IsActive,
        UpdatedAt = GETUTCDATE(),
        UpdatedBy = @UpdatedBy
    WHERE Id = @TemplateId;
END
GO

-- =============================================
-- EmailTemplate_Delete
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[emailCampaign].[EmailTemplate_Delete]') AND type in (N'P'))
    DROP PROCEDURE [emailCampaign].[EmailTemplate_Delete];
GO

CREATE PROCEDURE [emailCampaign].[EmailTemplate_Delete]
    @TemplateId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM [emailCampaign].[EmailTemplates]
    WHERE Id = @TemplateId;
END
GO

PRINT 'Email template stored procedures created successfully!';
GO
