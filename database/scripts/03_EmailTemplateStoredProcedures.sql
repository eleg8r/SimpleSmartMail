-- =============================================
-- Email Template Stored Procedures
-- =============================================

USE SimpleSmartMailDb;
GO

-- =============================================
-- sp_EmailTemplate_Create
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_EmailTemplate_Create]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_EmailTemplate_Create];
GO

CREATE PROCEDURE [dbo].[sp_EmailTemplate_Create]
    @TenantId NVARCHAR(50),
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

    INSERT INTO EmailTemplates (
        TenantId, Name, Description, Subject,
        HtmlTemplate, TextTemplate, IsActive,
        CreatedAt, CreatedBy
    )
    VALUES (
        @TenantId, @Name, @Description, @Subject,
        @HtmlTemplate, @TextTemplate, @IsActive,
        GETUTCDATE(), @CreatedBy
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS TemplateId;
END
GO

-- =============================================
-- sp_EmailTemplate_GetById
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_EmailTemplate_GetById]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_EmailTemplate_GetById];
GO

CREATE PROCEDURE [dbo].[sp_EmailTemplate_GetById]
    @TemplateId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, Name, Description, Subject,
        HtmlTemplate, TextTemplate, IsActive,
        CreatedAt, UpdatedAt, CreatedBy, UpdatedBy
    FROM EmailTemplates
    WHERE Id = @TemplateId;
END
GO

-- =============================================
-- sp_EmailTemplate_GetByTenantId
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_EmailTemplate_GetByTenantId]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_EmailTemplate_GetByTenantId];
GO

CREATE PROCEDURE [dbo].[sp_EmailTemplate_GetByTenantId]
    @TenantId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TenantId, Name, Description, Subject,
        HtmlTemplate, TextTemplate, IsActive,
        CreatedAt, UpdatedAt, CreatedBy, UpdatedBy
    FROM EmailTemplates
    WHERE TenantId = @TenantId
    ORDER BY CreatedAt DESC;
END
GO

-- =============================================
-- sp_EmailTemplate_Update
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_EmailTemplate_Update]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_EmailTemplate_Update];
GO

CREATE PROCEDURE [dbo].[sp_EmailTemplate_Update]
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

    UPDATE EmailTemplates
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
-- sp_EmailTemplate_Delete
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_EmailTemplate_Delete]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[sp_EmailTemplate_Delete];
GO

CREATE PROCEDURE [dbo].[sp_EmailTemplate_Delete]
    @TemplateId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM EmailTemplates
    WHERE Id = @TemplateId;
END
GO

PRINT 'Email template stored procedures created successfully!';
GO
