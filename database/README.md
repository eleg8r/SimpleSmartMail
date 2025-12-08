# SimpleSmartMail Database Documentation

## Overview

SimpleSmartMail uses SQL Server with a stored procedure-based data access layer. All database operations are performed through stored procedures for security, performance, and maintainability.

---

## Quick Setup

### Option 1: Run All Scripts Individually (Recommended)
```bash
# Run these in order:
sqlcmd -S localhost -U sa -P YourPassword -i database/scripts/01_CreateSchema.sql
sqlcmd -S localhost -U sa -P YourPassword -i database/scripts/02_EmailStoredProcedures.sql
sqlcmd -S localhost -U sa -P YourPassword -i database/scripts/03_EmailTemplateStoredProcedures.sql
sqlcmd -S localhost -U sa -P YourPassword -i database/scripts/04_CampaignStoredProcedures.sql
sqlcmd -S localhost -U sa -P YourPassword -i database/scripts/05_TrackingTablesAndProcedures.sql
```

### Option 2: Master Setup Script
```bash
sqlcmd -S localhost -U sa -P YourPassword -i database/scripts/00_MasterSetup.sql
```
Then run scripts 02-05 for stored procedures.

---

## Database Schema

### Tables (8 Total)

| Table | Purpose | Key Features |
|-------|---------|--------------|
| **Emails** | Individual email records | Tracking, status, attachments |
| **EmailAttachments** | File attachments | Binary storage, metadata |
| **EmailTemplates** | Reusable templates | HTML/text, personalization |
| **EmailCampaigns** | Bulk campaigns | Batch sending, statistics |
| **CampaignRecipients** | Campaign recipient list | Personalization, send status |
| **Tenants** | Multi-tenant config | API keys, limits, settings |
| **EmailClicks** | Click tracking | URL, IP, geolocation, device |
| **UnsubscribeRequests** | Opt-out management | Global/campaign-specific |

---

## Stored Procedures (32 Total)

### Email Procedures (7)
- `sp_Email_Create` - Create new email record
- `sp_Email_GetById` - Retrieve email by ID
- `sp_Email_GetByTrackingId` - Retrieve email by tracking GUID
- `sp_Email_GetByTenantId` - List emails for tenant (paginated)
- `sp_Email_Update` - Update all email fields
- `sp_Email_UpdateStatus` - **SimpleSmartMail-specific** - Update only status (lighter weight)
- `sp_EmailAttachment_Create` - Add attachment to email

### Template Procedures (5)
- `sp_EmailTemplate_Create` - Create new template
- `sp_EmailTemplate_GetById` - Retrieve template by ID
- `sp_EmailTemplate_GetByTenantId` - List templates for tenant
- `sp_EmailTemplate_Update` - Update template
- `sp_EmailTemplate_Delete` - Delete template

### Campaign Procedures (8)
- `sp_Campaign_Create` - Create new campaign
- `sp_Campaign_GetById` - Retrieve campaign by ID
- `sp_Campaign_GetByTenantId` - List campaigns for tenant
- `sp_Campaign_Update` - Update campaign details
- `sp_Campaign_UpdateStatistics` - Increment statistics counters
- `sp_CampaignRecipient_Create` - Add recipient to campaign
- `sp_CampaignRecipient_GetByCampaignId` - Get all campaign recipients
- `sp_CampaignRecipient_Update` - Update recipient send status

### Tenant Procedures (5)
- `sp_Tenant_Create` - Create new tenant
- `sp_Tenant_GetById` - Retrieve tenant by database ID
- `sp_Tenant_GetByTenantId` - Retrieve tenant by tenant ID
- `sp_Tenant_GetByApiKey` - Retrieve tenant by API key (with validation)
- `sp_Tenant_Update` - Update tenant configuration

### Tracking Procedures (7)
- `sp_Tracking_RecordOpen` - Record email open, update counters
- `sp_Tracking_RecordClick` - Record link click
- `sp_Tracking_GetClicksByEmailId` - Get clicks for specific email
- `sp_Tracking_GetClicksByCampaignId` - Get clicks for entire campaign
- `sp_Unsubscribe_Create` - Create unsubscribe request
- `sp_Unsubscribe_IsUnsubscribed` - Check if email is unsubscribed
- `sp_Unsubscribe_GetByTenantId` - List unsubscribes for tenant

---

## SimpleSmartMail-Specific Enhancements

### Differences from SmartMail

| Feature | SmartMail (EF Core) | SimpleSmartMail (Stored Procs) |
|---------|---------------------|--------------------------------|
| **sp_Email_UpdateStatus** | ❌ Not needed (EF updates entity) | ✅ Optimized for status-only updates |
| **Data Access** | Entity Framework LINQ | ADO.NET + SqlCommand |
| **Transactions** | Automatic via EF | Manual via procedures |
| **Performance** | Good (with compiled queries) | Excellent (direct SQL) |
| **Complexity** | Lower (ORM abstracts SQL) | Higher (manual mapping) |

### Why `sp_Email_UpdateStatus` Exists

In **SmartMail** with Entity Framework:
```csharp
var email = await context.Emails.FindAsync(id);
email.Status = EmailStatus.Sent;
await context.SaveChangesAsync();
```
EF generates optimized SQL that only updates the Status field.

In **SimpleSmartMail** with ADO.NET:
- `sp_Email_Update` requires 13 parameters (all fields)
- `sp_Email_UpdateStatus` requires only 2 parameters (ID + Status)
- **Result**: Faster, less network traffic, simpler calling code

**Usage Example:**
```csharp
// Full update (when you have all data)
await _emailRepository.UpdateAsync(email);  // Calls sp_Email_Update

// Status-only update (when you only need to change status)
await _emailRepository.UpdateStatusAsync(emailId, EmailStatus.Sent);  // Calls sp_Email_UpdateStatus
```

---

## Indexes

All tables have strategic indexes for performance:

### Primary Indexes
- **TenantId** - Multi-tenant filtering
- **CampaignId** - Campaign-related queries
- **TrackingId** - Tracking pixel/click lookups
- **EmailAddress** - Unsubscribe checks
- **ApiKey** - Authentication lookups

### Secondary Indexes
- **Status** - Filter by email status
- **CreatedAt** - Chronological sorting
- **ClickedAt** - Click analytics
- **IsActive** - Active templates/tenants

---

## Foreign Keys & Cascades

- **EmailAttachments** → Emails (CASCADE DELETE)
  - Deleting an email deletes its attachments

- **CampaignRecipients** → EmailCampaigns (CASCADE DELETE)
  - Deleting a campaign deletes its recipients

- **EmailClicks** → Emails (CASCADE DELETE)
  - Deleting an email deletes its click records

---

## Data Types

### Key Choices

| Column Type | SQL Type | Reason |
|-------------|----------|--------|
| IDs | `INT IDENTITY` | Auto-incrementing, 2B+ capacity |
| TenantId | `NVARCHAR(50)` | Human-readable identifiers |
| TrackingId | `UNIQUEIDENTIFIER` | Global uniqueness for tracking |
| Email Addresses | `NVARCHAR(255)` | RFC 5321 compliant |
| HTML/JSON | `NVARCHAR(MAX)` | Unlimited text storage |
| Timestamps | `DATETIME2` | Precision to 100 nanoseconds |
| File Content | `VARBINARY(MAX)` | Binary data up to 2GB |
| Flags | `BIT` | Boolean values |
| Counts | `INT` | 2B+ capacity for counters |

---

## Maintenance

### Backup Recommendation
```sql
-- Full backup daily
BACKUP DATABASE SimpleSmartMailDb
TO DISK = 'C:\Backups\SimpleSmartMail_Full.bak'
WITH COMPRESSION;

-- Transaction log backup hourly
BACKUP LOG SimpleSmartMailDb
TO DISK = 'C:\Backups\SimpleSmartMail_Log.trn'
WITH COMPRESSION;
```

### Index Maintenance
```sql
-- Rebuild fragmented indexes (run weekly)
ALTER INDEX ALL ON Emails REBUILD;
ALTER INDEX ALL ON EmailClicks REBUILD;
ALTER INDEX ALL ON EmailCampaigns REBUILD;
```

### Statistics Update
```sql
-- Update statistics (run after bulk imports)
UPDATE STATISTICS Emails;
UPDATE STATISTICS EmailCampaigns;
UPDATE STATISTICS CampaignRecipients;
```

---

## Version History

### Current Version: 1.0

**Created:**
- 8 tables for email, campaigns, tracking, tenants
- 32 stored procedures for all operations
- Indexes for performance
- Foreign keys for referential integrity

**SimpleSmartMail Enhancements:**
- `sp_Email_UpdateStatus` - Status-only updates
- Optimized for stored procedure architecture
- No ORM overhead

---

## Connection String

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=SimpleSmartMailDb;User Id=sa;Password=YourPassword;TrustServerCertificate=True;"
  }
}
```

**Security Note:** Use SQL Server Authentication with strong passwords or Windows Authentication in production.

---

## Troubleshooting

### Common Issues

**1. Cannot create database**
```sql
-- Check permissions
SELECT HAS_PERMS_BY_NAME(null, null, 'CREATE DATABASE');
```

**2. Stored procedure not found**
```sql
-- List all procedures
SELECT name FROM sys.procedures ORDER BY name;
```

**3. Foreign key violation**
```sql
-- Check orphaned records
SELECT * FROM EmailAttachments ea
LEFT JOIN Emails e ON ea.EmailId = e.Id
WHERE e.Id IS NULL;
```

**4. Slow queries**
```sql
-- Check missing indexes
SELECT * FROM sys.dm_db_missing_index_details;
```

---

## See Also

- **API Documentation**: `/README.md`
- **Entity Models**: `/src/SimpleSmartMail.Models/Entities/`
- **Repository Implementations**: `/src/SimpleSmartMail.Data/Repositories/`
