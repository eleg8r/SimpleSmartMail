# SimpleSmartMail Refactoring Summary

## Overview
This document summarizes the comprehensive refactoring to:
1. Remove the Tenant concept from the codebase
2. Add the `EmailCampaignPrograms` table for program-to-campaign mapping
3. Move all tables to the `[emailCampaign]` schema
4. Update `UnsubscribeRequests` to use `ProgramId` instead of `TenantId`
5. Remove the `IsGlobal` flag from `UnsubscribeRequests` (NULL `ProgramId` = global unsubscribe)
6. Add `IsValid` column to Emails table to match .NET model

## Database Changes Completed

### ✅ 01_CreateSchema.sql - UPDATED
**Changes:**
- Created `[emailCampaign]` schema
- Removed `TenantId` from all tables
- Added `IsValid BIT NOT NULL DEFAULT 1` to Emails table
- Added new `EmailCampaignPrograms` table with many-to-many relationship
- Updated `UnsubscribeRequests`:
  - Replaced `TenantId` with `ProgramId INT NULL`
  - Removed `GlobalUnsubscribe` column
  - `ProgramId NULL` = global unsubscribe
- Removed `Tenants` table entirely
- Moved all tables to `[emailCampaign]` schema
- Removed `TenantId` indexes

### ✅ 02_EmailStoredProcedures.sql - UPDATED
**Changes:**
- Removed `@TenantId` parameter from `sp_Email_Create`
- Added `@IsValid` parameter to `sp_Email_Create` and `sp_Email_Update`
- Removed `TenantId` from all SELECT statements
- Replaced `sp_Email_GetByTenantId` with `sp_Email_GetAll` (pagination-only)
- Updated all procedures to use `[emailCampaign]` schema
- Updated table references: `Emails` → `[emailCampaign].[Emails]`

### 🔲 03_EmailTemplateStoredProcedures.sql - NEEDS UPDATE
**Required changes:**
- Remove `@TenantId` parameter from `sp_EmailTemplate_Create`
- Remove `TenantId` from all SELECT statements
- Remove `sp_EmailTemplate_GetByTenantId` procedure
- Add `sp_EmailTemplate_GetAll` procedure
- Update schema references: `[dbo]` → `[emailCampaign]`

### 🔲 04_CampaignStoredProcedures.sql - NEEDS UPDATE
**Required changes:**
- Remove `@TenantId` parameter from `sp_Campaign_Create`
- Remove `TenantId` from all SELECT statements
- Remove `sp_Campaign_GetByTenantId` procedure
- Add `sp_Campaign_GetAll` procedure
- Add stored procedures for `EmailCampaignPrograms`:
  - `sp_EmailCampaignPrograms_AddProgram`
  - `sp_EmailCampaignPrograms_RemoveProgram`
  - `sp_EmailCampaignPrograms_GetByCampaignId`
  - `sp_EmailCampaignPrograms_GetByProgramId`
- Update schema references: `[dbo]` → `[emailCampaign]`
- Update table references in procedures

### 🔲 05_TrackingTablesAndProcedures.sql - NEEDS UPDATE
**Required changes:**
- Remove entire `Tenants` table and all related procedures:
  - DROP `sp_Tenant_Create`
  - DROP `sp_Tenant_GetById`
  - DROP `sp_Tenant_GetByTenantId`
  - DROP `sp_Tenant_GetByApiKey`
  - DROP `sp_Tenant_Update`
- Update `sp_Unsubscribe_IsUnsubscribed`:
  - Replace `@TenantId` parameter with `@ProgramId`
  - Update WHERE clause: Check `ProgramId IS NULL OR ProgramId = @ProgramId`
  - Remove `GlobalUnsubscribe` column references
- Update `sp_Unsubscribe_Create`:
  - Replace `@TenantId` with `@ProgramId`
  - Remove `@GlobalUnsubscribe` parameter
- Update `sp_Unsubscribe_GetByTenantId`:
  - Rename to `sp_Unsubscribe_GetByProgramId`
  - Replace parameter
- Update `sp_Tracking_RecordClick`:
  - Remove `@TenantId` parameter
  - Remove `TenantId` from INSERT statement
- Update `EmailClicks` table references (remove `TenantId` column)
- Update schema references: `[dbo]` → `[emailCampaign]`

## .NET Code Changes Required

### 🔲 Entity Models - NEEDS UPDATE

**Files to update:**
1. `src/SimpleSmartMail.Models/Entities/Email.cs`
   - ✅ Already has `IsValid` property
   - ❌ Remove `TenantId` property (line 8)

2. `src/SimpleSmartMail.Models/Entities/EmailCampaign.cs`
   - ❌ Remove `TenantId` property (line 8)

3. `src/SimpleSmartMail.Models/Entities/EmailTemplate.cs`
   - ❌ Remove `TenantId` property

4. `src/SimpleSmartMail.Models/Entities/EmailClick.cs`
   - ❌ Remove `TenantId` property

5. `src/SimpleSmartMail.Models/Entities/UnsubscribeRequest.cs`
   - ❌ Replace `TenantId` with `ProgramId`
   - ❌ Remove `GlobalUnsubscribe` property
   - ❌ Add `ProgramId?` property (nullable int)

6. **NEW FILE NEEDED:** `src/SimpleSmartMail.Models/Entities/EmailCampaignProgram.cs`
```csharp
namespace SimpleSmartMail.Models.Entities;

public class EmailCampaignProgram
{
    public int EmailCampaignId { get; set; }
    public int ProgramId { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public string CreatedBy { get; set; } = string.Empty;
    public string? UpdatedBy { get; set; }
}
```

7. **DELETE:** `src/SimpleSmartMail.Models/Entities/Tenant.cs` (if exists)

### 🔲 DTOs - NEEDS UPDATE

**Files to update:**
1. `src/SimpleSmartMail.Models/DTOs/SendEmailRequest.cs`
   - Remove `TenantId` property

2. `src/SimpleSmartMail.Models/DTOs/CreateCampaignRequest.cs`
   - Remove `TenantId` property
   - Add `List<int> ProgramIds` property

3. `src/SimpleSmartMail.Models/DTOs/CreateTemplateRequest.cs`
   - Remove `TenantId` property

### 🔲 Repository Interfaces - NEEDS UPDATE

**Files to update:**
1. `src/SimpleSmartMail.Data/Repositories/IEmailRepository.cs`
   - Change `GetByTenantIdAsync` → `GetAllAsync`
   - Remove `tenantId` parameters

2. `src/SimpleSmartMail.Data/Repositories/ICampaignRepository.cs`
   - Change `GetByTenantIdAsync` → `GetAllAsync`
   - Remove `tenantId` parameters
   - Add methods for `EmailCampaignPrograms`:
     - `AddProgramAsync(int campaignId, int programId, string createdBy)`
     - `RemoveProgramAsync(int campaignId, int programId)`
     - `GetProgramsByCampaignIdAsync(int campaignId)`
     - `GetCampaignsByProgramIdAsync(int programId)`

3. `src/SimpleSmartMail.Data/Repositories/IEmailTemplateRepository.cs`
   - Change `GetByTenantIdAsync` → `GetAllAsync`
   - Remove `tenantId` parameters

4. `src/SimpleSmartMail.Data/Repositories/ITrackingRepository.cs` (if exists)
   - Update `IsUnsubscribedAsync` signature:
     - OLD: `(string emailAddress, string tenantId)`
     - NEW: `(string emailAddress, int? programId)`

5. **DELETE:** `src/SimpleSmartMail.Data/Repositories/ITenantRepository.cs` (if exists)

### 🔲 Repository Implementations - NEEDS UPDATE

**Files to update:**
1. `src/SimpleSmartMail.Data/Repositories/EmailRepository.cs`
   - Update all stored procedure calls to use `[emailCampaign]` schema
   - Remove `TenantId` from parameters
   - Update method implementations

2. `src/SimpleSmartMail.Data/Repositories/CampaignRepository.cs`
   - Update all stored procedure calls
   - Remove `TenantId` parameters
   - Implement `EmailCampaignPrograms` methods

3. `src/SimpleSmartMail.Data/Repositories/EmailTemplateRepository.cs`
   - Update stored procedure calls
   - Remove `TenantId` parameters

4. **DELETE:** `src/SimpleSmartMail.Data/Repositories/TenantRepository.cs` (if exists)

### 🔲 Service Interfaces - NEEDS UPDATE

**Files to update:**
1. `src/SimpleSmartMail.Business/Services/IEmailService.cs`
   - Remove `tenantId` parameters from method signatures

2. `src/SimpleSmartMail.Business/Services/ICampaignService.cs`
   - Remove `tenantId` parameters
   - Update `GetCampaignsByTenantIdAsync` → `GetAllCampaignsAsync`

3. `src/SimpleSmartMail.Business/Services/IEmailTemplateService.cs`
   - Remove `tenantId` parameters

4. `src/SimpleSmartMail.Business/Services/ITrackingService.cs`
   - Update `IsUnsubscribedAsync(string emailAddress, int? programId)`

5. **DELETE:** `src/SimpleSmartMail.Business/Services/ITenantService.cs` (if exists)

### 🔲 Service Implementations - NEEDS UPDATE

**Files to update:**
1. `src/SimpleSmartMail.Business/Services/EmailService.cs`
   - Line 101: Change `IsUnsubscribedAsync(request.ToAddress, request.TenantId)`
     - To: Need to determine programId from campaign or pass as parameter
   - Remove `TenantId` from Email entity creation (line 115)
   - Remove `TenantId` validation checks

2. `src/SimpleSmartMail.Business/Services/CampaignService.cs`
   - Line 41-43: Remove `TenantId` assignment
   - Line 214: Change `IsUnsubscribedAsync(recipient.EmailAddress, campaign.TenantId)`
     - To: Need programId from EmailCampaignPrograms
   - Update to handle `EmailCampaignPrograms` when creating campaigns

3. `src/SimpleSmartMail.Business/Services/EmailTemplateService.cs`
   - Remove `TenantId` handling

4. `src/SimpleSmartMail.Business/Services/TrackingService.cs`
   - Update `IsUnsubscribedAsync` implementation
   - Change stored procedure call parameter from `TenantId` to `ProgramId`

5. **DELETE:** `src/SimpleSmartMail.Business/Services/TenantService.cs` (if exists)

### 🔲 Controllers - NEEDS UPDATE

**Files to update:**
1. `src/SimpleSmartMail.API/Controllers/EmailController.cs`
   - Remove `TenantId` from request extraction/validation
   - Update action methods

2. `src/SimpleSmartMail.API/Controllers/CampaignController.cs`
   - Remove `TenantId` handling
   - Update `GetCampaigns` endpoint
   - Add endpoints for program mapping:
     - `POST /api/campaigns/{id}/programs`
     - `DELETE /api/campaigns/{id}/programs/{programId}`
     - `GET /api/campaigns/{id}/programs`

3. `src/SimpleSmartMail.API/Controllers/EmailTemplateController.cs`
   - Remove `TenantId` handling

4. **DELETE:** `src/SimpleSmartMail.API/Controllers/TenantController.cs` (if exists)

## Critical Design Decisions Needed

### ⚠️ Unsubscribe Logic with Programs

**Problem:** When checking if a user is unsubscribed, we need to know which program the email is associated with.

**Current code issues:**
- `EmailService.cs:101` checks unsubscribe with `TenantId`
- `CampaignService.cs:214` checks unsubscribe with `campaign.TenantId`

**Solution options:**

**Option 1: Pass ProgramId explicitly**
```csharp
// In SendEmailRequest
public int? ProgramId { get; set; }

// In EmailService
var isUnsubscribed = await _trackingService.IsUnsubscribedAsync(
    request.ToAddress,
    request.ProgramId);
```

**Option 2: Derive ProgramId from Campaign**
```csharp
// For campaign emails, get program from EmailCampaignPrograms
// For single emails, require ProgramId in request
if (email.CampaignId.HasValue)
{
    var programs = await _campaignRepository.GetProgramsByCampaignIdAsync(email.CampaignId.Value);
    // Check unsubscribe for each program
    foreach (var programId in programs)
    {
        if (await _trackingService.IsUnsubscribedAsync(email.ToAddress, programId))
            return blocked;
    }
}
```

**Option 3: Global-only unsubscribes** (simplest)
```csharp
// Always check with ProgramId = NULL (global unsubscribe only)
var isUnsubscribed = await _trackingService.IsUnsubscribedAsync(
    request.ToAddress,
    null); // Always global
```

**Recommendation:** Option 2 for campaigns, Option 1 for standalone emails

## Migration Strategy

### For Existing Data (if applicable)

If you have existing data in production:

```sql
-- 1. Backup existing data
SELECT * INTO Emails_Backup FROM [dbo].[Emails];
SELECT * INTO EmailCampaigns_Backup FROM [dbo].[EmailCampaigns];

-- 2. Create new schema
EXEC('CREATE SCHEMA [emailCampaign]');

-- 3. Migrate data (handled by new schema scripts with INSERT...SELECT)

-- 4. Drop old tables
DROP TABLE [dbo].[Tenants];
DROP TABLE [dbo].[Emails];
-- etc.
```

### For Fresh Start (recommended for development)

```sql
-- 1. Drop existing database
DROP DATABASE SimpleSmartMailDb;

-- 2. Run new scripts in order:
-- database/scripts/01_CreateSchema.sql
-- database/scripts/02_EmailStoredProcedures.sql
-- database/scripts/03_EmailTemplateStoredProcedures.sql (after update)
-- database/scripts/04_CampaignStoredProcedures.sql (after update)
-- database/scripts/05_TrackingTablesAndProcedures.sql (after update)
```

## Testing Checklist

After refactoring:

- [ ] Create a campaign
- [ ] Add programs to campaign via `EmailCampaignPrograms`
- [ ] Add recipients to campaign
- [ ] Send campaign emails
- [ ] Verify unsubscribe logic works (global and program-specific)
- [ ] Test email tracking (opens/clicks)
- [ ] Verify no `TenantId` references remain in error messages
- [ ] Check all API endpoints return correct data
- [ ] Verify database constraints are enforced

## Files Status Summary

### ✅ Completed
- `database/scripts/01_CreateSchema.sql`
- `database/scripts/02_EmailStoredProcedures.sql`

### 🔲 Remaining Database Scripts (3)
- `database/scripts/03_EmailTemplateStoredProcedures.sql`
- `database/scripts/04_CampaignStoredProcedures.sql`
- `database/scripts/05_TrackingTablesAndProcedures.sql`

### 🔲 Remaining .NET Files (~25-30)
- Entity models (5-6 files)
- DTOs (3-4 files)
- Repository interfaces (3-4 files)
- Repository implementations (3-4 files)
- Service interfaces (3-4 files)
- Service implementations (3-4 files)
- Controllers (2-3 files)

**Estimated remaining work:** 3-4 hours for experienced developer

## Next Steps

1. ✅ Complete remaining database stored procedure scripts
2. Update .NET entity models
3. Update DTOs
4. Update repositories
5. Update services (resolve ProgramId logic)
6. Update controllers
7. Test thoroughly
8. Commit changes to Git

---

**Created:** 2026-01-13
**Status:** In Progress
**Completed:** Database schema + Email procedures (2/5 DB scripts)
