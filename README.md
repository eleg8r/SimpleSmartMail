# SimpleSmartMail

A simplified email and campaign management system built with .NET 6.0, using a clean 3-layer architecture and stored procedures for all database operations.

## Overview

SimpleSmartMail is a streamlined version of SmartMail, designed without Domain-Driven Design (DDD) patterns and using stored procedures instead of Entity Framework. It provides essential email sending and campaign management capabilities.

## Architecture

**3-Layer Architecture:**
- **API Layer** (`SimpleSmartMail.API`): REST API with MVC controllers and Swagger documentation
- **Business Layer** (`SimpleSmartMail.Business`): Services and email provider abstractions
- **Data Layer** (`SimpleSmartMail.Data`): Repositories using ADO.NET with stored procedures
- **Models** (`SimpleSmartMail.Models`): Shared entities, DTOs, and enums

## Features

- **Email Sending**
  - Send individual emails with attachments
  - Support for HTML and text bodies
  - CC and BCC recipients
  - Multiple email providers (SMTP, SendGrid)
  - Automatic retry logic with exponential backoff
  - Email tracking (opens, clicks)

- **Email Templates**
  - Create and manage reusable email templates
  - HTML and text template support
  - Template personalization

- **Email Campaigns**
  - Create and manage email campaigns
  - Batch sending with rate limiting
  - Recipient personalization
  - Campaign statistics and tracking
  - Schedule campaigns for future sending

## Technology Stack

- **.NET 6.0**
- **SQL Server 2019+**
- **ADO.NET** for database access
- **ASP.NET Core Web API** with MVC pattern
- **Swagger/OpenAPI** for API documentation
- **SendGrid** for cloud email delivery
- **SMTP** for traditional email delivery

## Project Structure

```
SimpleSmartMail/
├── src/
│   ├── SimpleSmartMail.API/          # REST API controllers
│   │   ├── Controllers/
│   │   ├── Program.cs
│   │   └── appsettings.json
│   ├── SimpleSmartMail.Business/      # Business logic
│   │   ├── Services/
│   │   └── EmailProviders/
│   ├── SimpleSmartMail.Data/          # Data access
│   │   ├── Repositories/
│   │   └── Common/
│   └── SimpleSmartMail.Models/        # Shared models
│       ├── Entities/
│       ├── DTOs/
│       └── Enums/
└── database/
    └── scripts/                       # SQL scripts
        ├── 01_CreateSchema.sql
        ├── 02_EmailStoredProcedures.sql
        ├── 03_EmailTemplateStoredProcedures.sql
        └── 04_CampaignStoredProcedures.sql
```

## Database Schema

**Tables:**
- `Emails` - Individual email records
- `EmailAttachments` - Email attachments
- `EmailTemplates` - Reusable email templates
- `EmailCampaigns` - Campaign master records
- `CampaignRecipients` - Campaign recipient lists

**All operations use stored procedures:**
- Email operations: `sp_Email_Create`, `sp_Email_GetById`, `sp_Email_Update`, etc.
- Template operations: `sp_EmailTemplate_Create`, `sp_EmailTemplate_GetById`, etc.
- Campaign operations: `sp_Campaign_Create`, `sp_Campaign_GetById`, `sp_CampaignRecipient_Create`, etc.

## Setup Instructions

### Prerequisites

- .NET 6.0 SDK
- SQL Server 2019 or later
- SMTP server credentials OR SendGrid API key

### Database Setup

1. Execute the SQL scripts in order:
   ```bash
   sqlcmd -S localhost -U sa -P YourPassword -i database/scripts/01_CreateSchema.sql
   sqlcmd -S localhost -U sa -P YourPassword -i database/scripts/02_EmailStoredProcedures.sql
   sqlcmd -S localhost -U sa -P YourPassword -i database/scripts/03_EmailTemplateStoredProcedures.sql
   sqlcmd -S localhost -U sa -P YourPassword -i database/scripts/04_CampaignStoredProcedures.sql
   ```

2. Update the connection string in `appsettings.json`:
   ```json
   "ConnectionStrings": {
     "DefaultConnection": "Server=localhost;Database=SimpleSmartMailDb;User Id=sa;Password=YourPassword;TrustServerCertificate=True;"
   }
   ```

### Email Provider Configuration

**For SMTP (e.g., Gmail):**
```json
"EmailSettings": {
  "DefaultProvider": "Smtp",
  "Smtp": {
    "Host": "smtp.gmail.com",
    "Port": "587",
    "Username": "your-email@gmail.com",
    "Password": "your-app-password",
    "EnableSsl": "true"
  }
}
```

**For SendGrid:**
```json
"EmailSettings": {
  "DefaultProvider": "SendGrid",
  "SendGrid": {
    "ApiKey": "your-sendgrid-api-key"
  }
}
```

### Running the Application

1. Build the solution:
   ```bash
   dotnet build
   ```

2. Run the API:
   ```bash
   cd src/SimpleSmartMail.API
   dotnet run
   ```

3. Access Swagger UI:
   ```
   https://localhost:5001/swagger
   ```

## API Endpoints

### Email Endpoints

- `POST /api/email/send` - Send an email
- `GET /api/email/{id}` - Get email by ID
- `GET /api/email/tracking/{trackingId}` - Get email by tracking ID
- `GET /api/email/tenant/{tenantId}` - Get emails by tenant

### Template Endpoints

- `POST /api/emailtemplate` - Create a template
- `GET /api/emailtemplate/{id}` - Get template by ID
- `GET /api/emailtemplate/tenant/{tenantId}` - Get templates by tenant
- `PUT /api/emailtemplate/{id}` - Update a template
- `DELETE /api/emailtemplate/{id}` - Delete a template

### Campaign Endpoints

- `POST /api/campaign` - Create a campaign
- `GET /api/campaign/{id}` - Get campaign by ID
- `GET /api/campaign/tenant/{tenantId}` - Get campaigns by tenant
- `POST /api/campaign/{id}/start` - Start a campaign
- `PUT /api/campaign/{id}/status` - Update campaign status

## Example Usage

### Send a Simple Email

```json
POST /api/email/send
{
  "tenantId": "tenant-001",
  "fromAddress": "noreply@example.com",
  "fromName": "Example Team",
  "toAddress": "customer@example.com",
  "toName": "Customer Name",
  "subject": "Welcome to SimpleSmartMail",
  "htmlBody": "<h1>Welcome!</h1><p>Thanks for joining us.</p>",
  "sendImmediately": true
}
```

### Create an Email Campaign

```json
POST /api/campaign
{
  "tenantId": "tenant-001",
  "name": "Welcome Campaign",
  "description": "Welcome new users",
  "fromAddress": "noreply@example.com",
  "fromName": "Example Team",
  "subject": "Welcome {{name}}!",
  "htmlTemplate": "<h1>Welcome {{name}}!</h1>",
  "enableOpenTracking": true,
  "enableClickTracking": true,
  "recipients": [
    {
      "emailAddress": "user1@example.com",
      "recipientName": "User One",
      "personalizationData": {
        "name": "User One"
      }
    }
  ],
  "createdBy": "admin"
}
```

## Key Differences from SmartMail

| Aspect | SmartMail (DDD) | SimpleSmartMail |
|--------|----------------|-----------------|
| Architecture | Clean Architecture (4 layers) | 3-layer architecture |
| Domain Model | Rich domain models with behavior | Simple POCOs |
| Value Objects | EmailAddress, EmailContent, etc. | Primitive types (strings) |
| Aggregate Roots | EmailCampaign, Email | None |
| Data Access | Entity Framework Core | ADO.NET + Stored Procedures |
| CQRS | MediatR with commands/queries | Direct service calls |
| Domain Events | Yes | No |
| Complexity | High (enterprise-grade) | Low (simplified) |

## Future Enhancements

- Email tracking and analytics dashboard
- Contact/recipient management system
- A/B testing for campaigns
- Drip campaign support
- Bounce handling and email validation
- Unsubscribe management
- Email scheduling with job queues

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.