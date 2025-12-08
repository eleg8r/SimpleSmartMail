# Auto-Token Generation - Usage Examples

## Overview

SimpleSmartMail can now automatically generate JWT authentication tokens for campaign recipients. This eliminates the need to manually create tokens for each recipient.

## Features

1. **Automatic Token Generation**: Tokens are generated server-side during campaign creation
2. **Configurable**: Enable/disable per campaign
3. **Flexible**: Customize token key name in PersonalizationData
4. **Secure**: Uses JWT with HMAC-SHA256 signatures
5. **Error Handling**: Continues processing if token generation fails for a recipient

---

## Configuration

### 1. appsettings.json

Ensure AutoAuth section is configured:

```json
{
  "AutoAuth": {
    "SecretKey": "your-super-secret-key-min-32-chars-long-change-this-in-production!",
    "Issuer": "SimpleSmartMail",
    "Audience": "leo.tutor.com",
    "ExpiryMinutes": 60
  }
}
```

**IMPORTANT:** Use the **SAME SecretKey** on both SimpleSmartMail and leo.tutor.com!

### 2. Service Registration

Already configured in `Program.cs`:

```csharp
builder.Services.AddScoped<IAutoAuthTokenService, AutoAuthTokenService>();
```

---

## Usage Examples

### Example 1: Auto-Generate Tokens (Recommended)

**API Request:**

```json
POST /api/campaign
{
  "tenantId": "tutor-company",
  "name": "Weekly Tutor Reminders",
  "subject": "Your tutor is waiting, {{StudentName}}!",
  "htmlTemplate": "<html><body><h1>Hi {{StudentName}}</h1><p><a href='{{TutorConnectUrl}}'>Connect to Tutor Now</a></p></body></html>",
  "fromAddress": "noreply@tutor.com",
  "fromName": "Leo Tutoring",
  "enableOpenTracking": true,
  "enableClickTracking": true,
  "autoGenerateAuthTokens": true,
  "autoAuthBaseUrl": "https://leo.tutor.com",
  "autoAuthTokenKey": "TutorConnectUrl",
  "recipients": [
    {
      "emailAddress": "alice@example.com",
      "recipientName": "Alice Johnson",
      "userId": "user-alice-123",
      "personalizationData": {
        "StudentName": "Alice"
      }
    },
    {
      "emailAddress": "bob@example.com",
      "recipientName": "Bob Smith",
      "userId": "user-bob-456",
      "personalizationData": {
        "StudentName": "Bob"
      }
    }
  ]
}
```

**What Happens:**

1. Campaign is created
2. For each recipient with `userId`:
   - JWT token is generated with userId and email
   - Auto-login URL is created: `https://leo.tutor.com/ondemand?token=eyJ...`
   - URL is added to PersonalizationData as `TutorConnectUrl`
3. Email template replaces `{{TutorConnectUrl}}` with the actual URL
4. Emails are sent with working auto-login links

**Result Email for Alice:**

```html
<html>
<body>
  <h1>Hi Alice</h1>
  <p>
    <a href='https://leo.tutor.com/ondemand?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'>
      Connect to Tutor Now
    </a>
  </p>
</body>
</html>
```

---

### Example 2: Custom Token Key Name

Use a different key name in PersonalizationData:

```json
{
  "autoGenerateAuthTokens": true,
  "autoAuthBaseUrl": "https://leo.tutor.com",
  "autoAuthTokenKey": "LoginLink",
  "htmlTemplate": "<html><body><a href='{{LoginLink}}'>Login</a></body></html>",
  "recipients": [
    {
      "emailAddress": "user@example.com",
      "userId": "user-123",
      "personalizationData": {
        "Name": "Alice"
      }
    }
  ]
}
```

Token URL will be added as `LoginLink` in PersonalizationData.

---

### Example 3: Mixed Recipients (Some with UserId, Some without)

```json
{
  "autoGenerateAuthTokens": true,
  "autoAuthBaseUrl": "https://leo.tutor.com",
  "recipients": [
    {
      "emailAddress": "alice@example.com",
      "userId": "user-alice-123",
      "personalizationData": {
        "StudentName": "Alice"
      }
    },
    {
      "emailAddress": "bob@example.com",
      "recipientName": "Bob Smith",
      "personalizationData": {
        "StudentName": "Bob",
        "TutorConnectUrl": "https://leo.tutor.com/login"
      }
    }
  ]
}
```

**Result:**
- Alice: Auto-generated token URL is added
- Bob: No token generated (no userId), uses existing URL in PersonalizationData

---

### Example 4: Manual Token Generation (Option 1)

If you prefer full control, generate tokens manually:

```json
{
  "autoGenerateAuthTokens": false,
  "recipients": [
    {
      "emailAddress": "alice@example.com",
      "personalizationData": {
        "StudentName": "Alice",
        "TutorConnectUrl": "https://leo.tutor.com/ondemand?token=eyJhbGc..."
      }
    }
  ]
}
```

Generate tokens in your application code:

```csharp
var autoAuthService = serviceProvider.GetRequiredService<IAutoAuthTokenService>();

var recipients = new List<CampaignRecipientDto>
{
    new CampaignRecipientDto
    {
        EmailAddress = "alice@example.com",
        RecipientName = "Alice Johnson",
        PersonalizationData = new Dictionary<string, string>
        {
            { "StudentName", "Alice" },
            { "TutorConnectUrl", autoAuthService.GenerateTutorConnectUrl(
                userId: "user-alice-123",
                email: "alice@example.com",
                baseUrl: "https://leo.tutor.com"
            )}
        }
    }
};
```

---

## API Request Properties

### CreateCampaignRequest

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `autoGenerateAuthTokens` | bool | No | false | Enable automatic token generation |
| `autoAuthBaseUrl` | string | Conditional | null | Base URL for auto-auth (required if autoGenerateAuthTokens = true) |
| `autoAuthTokenKey` | string | No | "TutorConnectUrl" | Key name in PersonalizationData for the token URL |

### CampaignRecipientDto

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `userId` | string | No | User identifier for token generation (required for auto-token generation) |
| `emailAddress` | string | Yes | Recipient email address |
| `recipientName` | string | No | Recipient display name |
| `personalizationData` | Dictionary<string, string> | No | Custom data for template replacement |

---

## Token Generation Logic

### When Tokens Are Generated

Tokens are generated IF:
1. `autoGenerateAuthTokens` is `true` AND
2. `autoAuthBaseUrl` is not empty AND
3. Recipient has a non-empty `userId`

### What's Included in the Token

JWT contains the following claims:
- `sub` (NameIdentifier): User ID
- `email`: User email address
- `jti`: Unique token ID (GUID)
- `purpose`: "auto-login"
- `generated_at`: Unix timestamp
- `iss`: Issuer (from config)
- `aud`: Audience (from config)
- `exp`: Expiry time (from config)

### Token Format

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLWFsaWNlLTEyMyIsImVtYWlsIjoiYWxpY2VAZXhhbXBsZS5jb20iLCJqdGkiOiI3ODkwYWJjZC0xMjM0LTU2NzgtOTBhYi1jZGVmMTIzNDU2NzgiLCJwdXJwb3NlIjoiYXV0by1sb2dpbiIsImdlbmVyYXRlZF9hdCI6IjE3MDAwMDAwMDAiLCJpc3MiOiJTaW1wbGVTbWFydE1haWwiLCJhdWQiOiJsZW8udHV0b3IuY29tIiwiZXhwIjoxNzAwMDAzNjAwfQ.signature
```

Decode at [jwt.io](https://jwt.io) to inspect claims.

---

## Error Handling

### Recipient-Level Errors

If token generation fails for a recipient:
- Error is logged
- Campaign creation continues
- Other recipients are processed normally
- Recipient without token is still added to campaign

### Campaign-Level Configuration Errors

If AutoAuth configuration is missing or invalid:
- `AutoAuthTokenService` throws `InvalidOperationException`
- Campaign creation fails
- Error message indicates configuration issue

**Example Error:**

```
AutoAuth:SecretKey is not configured. Please add it to appsettings.json
```

---

## Security Best Practices

### 1. Secret Key Management

**Development (appsettings.json):**
```json
{
  "AutoAuth": {
    "SecretKey": "dev-secret-key-minimum-32-characters-long"
  }
}
```

**Production (Environment Variables):**
```bash
export AutoAuth__SecretKey="prod-secret-key-from-azure-key-vault"
```

### 2. Token Expiry

Set appropriate expiry based on use case:
- **Short-lived links (1 hour)**: Default, recommended
- **Daily reminders (24 hours)**: `"ExpiryMinutes": 1440`
- **Weekly links (7 days)**: `"ExpiryMinutes": 10080`

### 3. HTTPS Only

Always use HTTPS for AutoAuthBaseUrl:
- ✅ `https://leo.tutor.com`
- ❌ `http://leo.tutor.com`

### 4. User ID Validation

Ensure userId values are:
- Unique per user
- Not guessable
- From trusted source (your user database)

---

## Testing

### Test 1: Verify Token Generation

```bash
curl -X POST https://localhost:5001/api/campaign \
  -H "Content-Type: application/json" \
  -d '{
    "tenantId": "test",
    "name": "Test Campaign",
    "subject": "Test",
    "htmlTemplate": "<a href=\"{{TutorConnectUrl}}\">Login</a>",
    "fromAddress": "test@example.com",
    "fromName": "Test",
    "autoGenerateAuthTokens": true,
    "autoAuthBaseUrl": "https://leo.tutor.com",
    "recipients": [
      {
        "emailAddress": "user@example.com",
        "userId": "test-user-123"
      }
    ]
  }'
```

**Expected:**
- Campaign created successfully
- Check database: `PersonalizationData` contains `TutorConnectUrl` with JWT token

### Test 2: Verify Token Claims

Copy JWT token from database, decode at [jwt.io](https://jwt.io):

**Expected Claims:**
```json
{
  "sub": "test-user-123",
  "email": "user@example.com",
  "jti": "unique-guid",
  "purpose": "auto-login",
  "iss": "SimpleSmartMail",
  "aud": "leo.tutor.com",
  "exp": 1700003600
}
```

### Test 3: Verify Token Works on leo.tutor.com

1. Get token URL from sent email
2. Click link or paste in browser
3. Should redirect to leo.tutor.com/ondemand?token=...
4. leo.tutor.com validates token and logs user in

---

## Comparison: Auto vs Manual

### Auto-Generate Tokens (Option 2)

**Pros:**
- ✅ Simpler API requests
- ✅ No client-side token generation
- ✅ Consistent token format
- ✅ Centralized security configuration

**Cons:**
- ❌ Requires UserId for each recipient
- ❌ Less flexible for custom claims

**Use When:**
- You have user IDs readily available
- You want simplicity
- You trust server-side token generation

### Manual Tokens (Option 1)

**Pros:**
- ✅ Full control over token claims
- ✅ Can add custom data
- ✅ Generate tokens anywhere

**Cons:**
- ❌ More complex API requests
- ❌ Need to implement token generation client-side
- ❌ Must ensure security

**Use When:**
- You need custom claims
- You generate tokens in another service
- You have specific security requirements

---

## Troubleshooting

### Issue: Tokens Not Generated

**Check:**
1. `autoGenerateAuthTokens` is `true`
2. `autoAuthBaseUrl` is not empty
3. Recipients have `userId` values
4. AutoAuth configuration exists in appsettings.json

### Issue: Invalid Token Error

**Check:**
1. SecretKey matches on both systems
2. Token hasn't expired
3. Issuer and Audience match configuration
4. Clock skew is acceptable

### Issue: Missing TutorConnectUrl in Email

**Check:**
1. Token key name matches template: `{{TutorConnectUrl}}`
2. Token generation succeeded (check logs)
3. PersonalizationData was saved to database

---

## Complete Example: Tutoring Platform

### API Request

```json
POST /api/campaign
{
  "tenantId": "tutor-platform",
  "name": "Daily Session Reminders",
  "subject": "Your session starts in 1 hour, {{StudentName}}!",
  "htmlTemplate": "
    <html>
    <body style='font-family: Arial, sans-serif;'>
      <h1>Hi {{StudentName}}! 👋</h1>
      <p>Your tutoring session with {{TutorName}} starts at {{SessionTime}}.</p>
      <div style='text-align: center; margin: 30px 0;'>
        <a href='{{TutorConnectUrl}}'
           style='background: #4CAF50; color: white; padding: 15px 30px;
                  text-decoration: none; border-radius: 5px; font-size: 18px;'>
          Join Session Now
        </a>
      </div>
      <p style='color: #666; font-size: 12px;'>
        Session ID: {{SessionId}}<br>
        Duration: {{Duration}} minutes
      </p>
    </body>
    </html>
  ",
  "fromAddress": "sessions@tutor.com",
  "fromName": "Leo Tutoring Platform",
  "enableOpenTracking": true,
  "enableClickTracking": true,
  "autoGenerateAuthTokens": true,
  "autoAuthBaseUrl": "https://leo.tutor.com",
  "recipients": [
    {
      "emailAddress": "alice@example.com",
      "recipientName": "Alice Johnson",
      "userId": "user-alice-123",
      "personalizationData": {
        "StudentName": "Alice",
        "TutorName": "Dr. Smith",
        "SessionTime": "2:00 PM EST",
        "SessionId": "session-789",
        "Duration": "60"
      }
    },
    {
      "emailAddress": "bob@example.com",
      "recipientName": "Bob Smith",
      "userId": "user-bob-456",
      "personalizationData": {
        "StudentName": "Bob",
        "TutorName": "Prof. Johnson",
        "SessionTime": "3:30 PM EST",
        "SessionId": "session-790",
        "Duration": "45"
      }
    }
  ]
}
```

### Result

**Alice's Email:**
- Subject: "Your session starts in 1 hour, Alice!"
- Body contains personalized info
- "Join Session Now" button links to: `https://leo.tutor.com/ondemand?token=eyJ...`
- Click tracking enabled
- Open tracking pixel injected
- Unsubscribe link added

**When Alice clicks "Join Session Now":**
1. Browser goes to leo.tutor.com/ondemand?token=...
2. leo.tutor.com validates JWT token
3. Extracts userId: "user-alice-123"
4. Creates authentication cookie
5. Redirects to tutoring dashboard
6. Alice is logged in and ready for session!

---

## Summary

✅ **Auto-token generation is now implemented**
✅ **Add `userId` to recipients**
✅ **Enable with `autoGenerateAuthTokens: true`**
✅ **Tokens automatically added to PersonalizationData**
✅ **Works seamlessly with tracking features**
✅ **Secure JWT-based authentication**

**Next Step:** Implement token validation on leo.tutor.com (see AUTO_AUTHENTICATION_GUIDE.md)
