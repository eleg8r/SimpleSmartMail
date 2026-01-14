# SimpleSmartMail Refactoring Status

**Last Updated:** 2026-01-14
**Branch:** `claude/refactor-remove-tenant-Vs358`
**Status:** Database & Models Complete | Services Pending

---

## ✅ Completed Work

### 1. Database Schema (100% Complete)
All database scripts have been refactored to remove Tenant concept and add Program support.

**Files Updated:**
- ✅ `database/scripts/01_CreateSchema.sql`
  - Created `[emailCampaign]` schema
  - Removed `TenantId` from all tables
  - Added `IsValid` column to Emails table
  - Added `EmailCampaignPrograms` table (many-to-many)
  - Updated `UnsubscribeRequests` (replaced `TenantId` with `ProgramId`, removed `IsGlobal`)
  - Removed `Tenants` table completely

- ✅ `database/scripts/02_EmailStoredProcedures.sql`
  - Removed `@TenantId` parameters
  - Added `@IsValid` parameter
  - Replaced `sp_Email_GetByTenantId` with `sp_Email_GetAll`
  - Updated all procedures to use `[emailCampaign]` schema

- ✅ `database/scripts/03_EmailTemplateStoredProcedures.sql`
  - Removed `@TenantId` parameters
  - Added `sp_EmailTemplate_GetAll` with optional active filter
  - Updated all procedures to use `[emailCampaign]` schema

- ✅ `database/scripts/04_CampaignStoredProcedures.sql`
  - Removed `@TenantId` parameters
  - Added `sp_Campaign_GetAll` with pagination
  - **NEW:** Added EmailCampaignPrograms procedures:
    - `sp_EmailCampaignPrograms_AddProgram`
    - `sp_EmailCampaignPrograms_RemoveProgram`
    - `sp_EmailCampaignPrograms_GetByCampaignId`
    - `sp_EmailCampaignPrograms_GetByProgramId`
  - Updated all procedures to use `[emailCampaign]` schema

- ✅ `database/scripts/05_TrackingTablesAndProcedures.sql`
  - Removed all Tenant-related tables and procedures
  - Removed `@TenantId` from `sp_Tracking_RecordClick`
  - Updated UnsubscribeRequests procedures:
    - `sp_Unsubscribe_IsUnsubscribed(@EmailAddress, @ProgramId)` - checks global or program-specific
    - `sp_Unsubscribe_Create` uses `@ProgramId` (NULL = global)
    - `sp_Unsubscribe_GetByProgramId` (NULL = get global unsubscribes)
    - `sp_Unsubscribe_GetAll` with pagination
  - Updated all procedures to use `[emailCampaign]` schema

### 2. Entity Models (100% Complete)

**Files Updated:**
- ✅ `src/SimpleSmartMail.Models/Entities/Email.cs` - Removed `TenantId`
- ✅ `src/SimpleSmartMail.Models/Entities/EmailCampaign.cs` - Removed `TenantId`
- ✅ `src/SimpleSmartMail.Models/Entities/EmailTemplate.cs` - Removed `TenantId`
- ✅ `src/SimpleSmartMail.Models/Entities/EmailClick.cs` - Removed `TenantId`
- ✅ `src/SimpleSmartMail.Models/Entities/UnsubscribeRequest.cs` - Replaced `TenantId` with `ProgramId?`, removed `GlobalUnsubscribe`
- ✅ **NEW:** `src/SimpleSmartMail.Models/Entities/EmailCampaignProgram.cs` - Many-to-many mapping

**Files Deleted:**
- ✅ `src/SimpleSmartMail.Models/Entities/Tenant.cs`

### 3. DTOs (100% Complete)

**Files Updated:**
- ✅ `src/SimpleSmartMail.Models/DTOs/SendEmailRequest.cs`
  - Removed `TenantId`
  - Added `ProgramId?` (optional, for unsubscribe checks)

- ✅ `src/SimpleSmartMail.Models/DTOs/CreateCampaignRequest.cs`
  - Removed `TenantId`
  - Added `List<int> ProgramIds` (required, min 1 program)

- ✅ `src/SimpleSmartMail.Models/DTOs/CreateTemplateRequest.cs`
  - Removed `TenantId`

### 4. Documentation
- ✅ `REFACTORING_SUMMARY.md` - Comprehensive refactoring guide
- ✅ `REFACTORING_STATUS.md` - This file

---

## 🔲 Remaining Work

The core data structures are complete. The remaining work involves updating the application logic to use the new structure.

### 1. Repository Interfaces (Estimated: 30 mins)

**Files to Update:**
- `src/SimpleSmartMail.Data/Repositories/IEmailRepository.cs`
  - Change `GetByTenantIdAsync` → `GetAllAsync`

- `src/SimpleSmartMail.Data/Repositories/ICampaignRepository.cs`
  - Change `GetByTenantIdAsync` → `GetAllAsync`
  - Add: `Task<List<EmailCampaignProgram>> GetProgramsByCampaignIdAsync(int campaignId)`
  - Add: `Task AddProgramAsync(int campaignId, int programId, string createdBy)`
  - Add: `Task RemoveProgramAsync(int campaignId, int programId)`

- `src/SimpleSmartMail.Data/Repositories/IEmailTemplateRepository.cs`
  - Change `GetByTenantIdAsync` → `GetAllAsync`

- **Delete:** `src/SimpleSmartMail.Data/Repositories/ITenantRepository.cs` (if exists)

### 2. Repository Implementations (Estimated: 1 hour)

**Files to Update:**
- `src/SimpleSmartMail.Data/Repositories/EmailRepository.cs`
  - Update stored procedure calls to use `[emailCampaign]` schema
  - Remove `TenantId` parameters from all method calls

- `src/SimpleSmartMail.Data/Repositories/CampaignRepository.cs`
  - Update stored procedure calls to use `[emailCampaign]` schema
  - Remove `TenantId` parameters
  - Implement EmailCampaignPrograms methods

- `src/SimpleSmartMail.Data/Repositories/EmailTemplateRepository.cs`
  - Update stored procedure calls
  - Remove `TenantId` parameters

- **Delete:** `src/SimpleSmartMail.Data/Repositories/TenantRepository.cs` (if exists)

### 3. Service Interfaces (Estimated: 20 mins)

**Files to Update:**
- `src/SimpleSmartMail.Business/Services/IEmailService.cs`
  - Remove `tenantId` parameters

- `src/SimpleSmartMail.Business/Services/ICampaignService.cs`
  - Remove `tenantId` parameters
  - Change `GetCampaignsByTenantIdAsync` → `GetAllCampaignsAsync`

- `src/SimpleSmartMail.Business/Services/IEmailTemplateService.cs`
  - Remove `tenantId` parameters

- `src/SimpleSmartMail.Business/Services/ITrackingService.cs`
  - Update: `IsUnsubscribedAsync(string emailAddress, int? programId)`

- **Delete:** `src/SimpleSmartMail.Business/Services/ITenantService.cs` (if exists)

### 4. Service Implementations (Estimated: 2 hours) ⚠️ CRITICAL

This is the most complex part requiring careful logic updates.

**Files to Update:**

**A. `src/SimpleSmartMail.Business/Services/EmailService.cs`**

Critical changes needed:
```csharp
// Line 101 - OLD:
var isUnsubscribed = await _trackingService.IsUnsubscribedAsync(
    request.ToAddress,
    request.TenantId);

// NEW:
var isUnsubscribed = await _trackingService.IsUnsubscribedAsync(
    request.ToAddress,
    request.ProgramId);

// Line 115 - Remove TenantId assignment:
var email = new Email
{
    // TenantId = request.TenantId, // DELETE THIS LINE
    FromAddress = request.FromAddress,
    ...
};
```

**B. `src/SimpleSmartMail.Business/Services/CampaignService.cs`**

Critical changes needed:
```csharp
// Line 41-43 - Remove TenantId:
var campaign = new EmailCampaign
{
    // TenantId = request.TenantId, // DELETE THIS LINE
    Name = request.Name,
    ...
};

// Line 62 - After creating campaign, add programs:
var campaignId = await _campaignRepository.CreateAsync(campaign);

// ADD THIS: Map programs to campaign
foreach (var programId in request.ProgramIds)
{
    await _campaignRepository.AddProgramAsync(campaignId, programId, request.CreatedBy);
}

// Line 214 - Update unsubscribe check:
// OLD:
var isUnsubscribed = await _trackingService.IsUnsubscribedAsync(
    recipient.EmailAddress,
    campaign.TenantId);

// NEW: Get programs for this campaign and check each
var programs = await _campaignRepository.GetProgramsByCampaignIdAsync(campaign.Id);
foreach (var program in programs)
{
    if (await _trackingService.IsUnsubscribedAsync(recipient.EmailAddress, program.ProgramId))
    {
        _logger.LogInformation("Skipping unsubscribed recipient...");
        recipient.Sent = false;
        await _campaignRepository.UpdateRecipientAsync(recipient);
        emailsFailed++;
        continue; // Skip to next recipient
    }
}
```

**C. `src/SimpleSmartMail.Business/Services/EmailTemplateService.cs`**
- Remove all `TenantId` references

**D. `src/SimpleSmartMail.Business/Services/TrackingService.cs`**
- Update `IsUnsubscribedAsync` to use `ProgramId` parameter

**E. Delete:**
- `src/SimpleSmartMail.Business/Services/TenantService.cs` (if exists)

### 5. Controllers (Estimated: 1 hour)

**Files to Update:**

**A. `src/SimpleSmartMail.API/Controllers/EmailController.cs`**
- Remove `TenantId` extraction from requests
- Remove `TenantId` validation

**B. `src/SimpleSmartMail.API/Controllers/CampaignController.cs`**
- Remove `TenantId` handling
- Update `GetCampaigns` endpoint
- **Add new endpoints:**
  ```csharp
  [HttpPost("{id}/programs")]
  public async Task<IActionResult> AddProgram(int id, [FromBody] AddProgramRequest request)

  [HttpDelete("{id}/programs/{programId}")]
  public async Task<IActionResult> RemoveProgram(int id, int programId)

  [HttpGet("{id}/programs")]
  public async Task<IActionResult> GetPrograms(int id)

  [HttpGet("programs/{programId}")]
  public async Task<IActionResult> GetCampaignsByProgram(int programId)
  ```

**C. `src/SimpleSmartMail.API/Controllers/EmailTemplateController.cs`**
- Remove `TenantId` handling

**D. Delete:**
- `src/SimpleSmartMail.API/Controllers/TenantController.cs` (if exists)

---

## 📊 Progress Summary

| Component | Status | Files Changed | Completion |
|-----------|--------|---------------|-----------|
| **Database Scripts** | ✅ Complete | 5/5 | 100% |
| **Entity Models** | ✅ Complete | 7/7 | 100% |
| **DTOs** | ✅ Complete | 3/3 | 100% |
| **Repository Interfaces** | 🔲 Pending | 0/3 | 0% |
| **Repository Implementations** | 🔲 Pending | 0/3 | 0% |
| **Service Interfaces** | 🔲 Pending | 0/4 | 0% |
| **Service Implementations** | 🔲 Pending | 0/4 | 0% |
| **Controllers** | 🔲 Pending | 0/3 | 0% |
| **Overall Progress** | | **18/32** | **56%** |

---

## 🎯 Key Design Decisions

### Unsubscribe Logic

**Decision:** Program-aware unsubscribes with global fallback

**Implementation:**
- `ProgramId = NULL` → Global unsubscribe (blocks all emails)
- `ProgramId = X` → Program-specific unsubscribe (blocks only Program X emails)
- Check: `WHERE EmailAddress = @Email AND (ProgramId IS NULL OR ProgramId = @ProgramId)`

**For Campaign Emails:**
- Retrieve all programs associated with campaign via `EmailCampaignPrograms`
- Check if user is unsubscribed from ANY of those programs
- If yes, skip sending to that recipient

**For Standalone Emails:**
- Use optional `ProgramId` from `SendEmailRequest`
- If null, only check global unsubscribes
- If specified, check both global and program-specific

### EmailCampaignPrograms Many-to-Many

**Rationale:** One campaign can target multiple programs (universities/school districts)

**Example:**
```
Campaign: "Spring 2026 Enrollment Reminder"
    → Program 1: University of California
    → Program 2: Stanford University
    → Program 3: MIT
```

All three institutions receive the same campaign but track separately.

---

##Remaining Effort Estimate

| Task | Time | Complexity |
|------|------|------------|
| Repository Interfaces | 30 min | Low |
| Repository Implementations | 1 hour | Medium |
| Service Interfaces | 20 min | Low |
| **Service Implementations** | **2 hours** | **High** ⚠️ |
| Controllers | 1 hour | Medium |
| Testing & Debugging | 1-2 hours | High |
| **Total** | **5-6 hours** | |

---

## 🚀 Next Steps

1. **Update Repository Interfaces** - Quick and straightforward
2. **Update Repository Implementations** - Medium complexity, follow existing patterns
3. **Update Service Interfaces** - Quick updates
4. **Update Service Implementations** - **Most critical** - requires careful ProgramId logic
5. **Update Controllers** - Add program mapping endpoints
6. **Test thoroughly** - Verify unsubscribe logic works correctly
7. **Update documentation** - Final README updates

---

## 📝 Git Commits Made

1. `e12098d` - Refactor: Remove Tenant concept and add EmailCampaignPrograms table (Database schema)
2. `e357c90` - Refactor: Update entity models to remove Tenant concept
3. `82c6632` - Refactor: Complete database stored procedures refactoring
4. `341f7ee` - Refactor: Update DTOs to remove TenantId and add Program support

**Total commits:** 4
**Files changed:** 18
**Lines added:** ~500
**Lines removed:** ~400

---

**Status:** Ready for Service layer implementation
