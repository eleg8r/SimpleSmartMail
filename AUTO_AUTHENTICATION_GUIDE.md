# Auto-Authentication Implementation Guide

## Overview

This guide shows how to implement auto-authentication for users clicking "Connect to Tutor" links in emails.

**Architecture:**
1. SimpleSmartMail (or your main app) generates secure JWT tokens
2. Tokens are added to PersonalizationData in emails
3. leo.tutor.com validates tokens and authenticates users
4. Users are redirected to protected pages

---

## Part 1: Token Generation Service (SimpleSmartMail)

### Step 1: Add JWT NuGet Package

```bash
dotnet add src/SimpleSmartMail.Business/SimpleSmartMail.Business.csproj package System.IdentityModel.Tokens.Jwt
dotnet add src/SimpleSmartMail.Business/SimpleSmartMail.Business.csproj package Microsoft.IdentityModel.Tokens
```

### Step 2: Create Token Generation Service

**File:** `/src/SimpleSmartMail.Business/Services/IAutoAuthTokenService.cs`

```csharp
namespace SimpleSmartMail.Business.Services;

public interface IAutoAuthTokenService
{
    string GenerateAutoLoginToken(string userId, string email, string? sessionId = null, Dictionary<string, string>? additionalClaims = null);
    string GenerateTutorConnectUrl(string userId, string email, string baseUrl);
}
```

**File:** `/src/SimpleSmartMail.Business/Services/AutoAuthTokenService.cs`

```csharp
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace SimpleSmartMail.Business.Services;

public class AutoAuthTokenService : IAutoAuthTokenService
{
    private readonly IConfiguration _configuration;

    public AutoAuthTokenService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public string GenerateAutoLoginToken(
        string userId,
        string email,
        string? sessionId = null,
        Dictionary<string, string>? additionalClaims = null)
    {
        var secretKey = _configuration["AutoAuth:SecretKey"] ?? throw new InvalidOperationException("AutoAuth:SecretKey not configured");
        var issuer = _configuration["AutoAuth:Issuer"] ?? "SimpleSmartMail";
        var audience = _configuration["AutoAuth:Audience"] ?? "leo.tutor.com";
        var expiryMinutes = _configuration.GetValue<int>("AutoAuth:ExpiryMinutes", 60);

        var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
        var credentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, userId),
            new Claim(ClaimTypes.Email, email),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new Claim("purpose", "auto-login")
        };

        if (!string.IsNullOrEmpty(sessionId))
        {
            claims.Add(new Claim("session_id", sessionId));
        }

        // Add any additional claims
        if (additionalClaims != null)
        {
            foreach (var claim in additionalClaims)
            {
                claims.Add(new Claim(claim.Key, claim.Value));
            }
        }

        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(expiryMinutes),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public string GenerateTutorConnectUrl(string userId, string email, string baseUrl)
    {
        var token = GenerateAutoLoginToken(userId, email);
        return $"{baseUrl}/ondemand?token={token}";
    }
}
```

### Step 3: Configure in appsettings.json

**File:** `/src/SimpleSmartMail.API/appsettings.json`

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

**⚠️ IMPORTANT:** Use the **SAME SecretKey** on both SimpleSmartMail and leo.tutor.com!

### Step 4: Register Service in Program.cs

**File:** `/src/SimpleSmartMail.API/Program.cs`

```csharp
// Add this with other service registrations
builder.Services.AddScoped<IAutoAuthTokenService, AutoAuthTokenService>();
```

### Step 5: Use in Campaign Creation

**Example API Request:**

```json
POST /api/campaign
{
  "tenantId": "tutor-company",
  "name": "Weekly Tutor Reminders",
  "subject": "Your tutor is waiting, {{StudentName}}!",
  "htmlTemplate": "<html><body><h1>Hi {{StudentName}}</h1><p>Ready for your session?</p><p><a href='{{TutorConnectUrl}}' style='background: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;'>Connect to Tutor Now</a></p></body></html>",
  "fromAddress": "noreply@tutor.com",
  "fromName": "Leo Tutoring",
  "recipients": [
    {
      "emailAddress": "alice@example.com",
      "recipientName": "Alice Johnson",
      "personalizationData": {
        "StudentName": "Alice",
        "TutorConnectUrl": "https://leo.tutor.com/ondemand?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
      }
    }
  ]
}
```

**Or generate dynamically in code:**

```csharp
var autoAuthService = new AutoAuthTokenService(configuration);

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

## Part 2: Token Validation & Authentication (leo.tutor.com)

### Step 1: Add JWT NuGet Package

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package System.IdentityModel.Tokens.Jwt
```

### Step 2: Configure JWT Authentication

**File:** `leo.tutor.com/Program.cs`

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Add Authentication & JWT Bearer
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer("AutoLogin", options =>
{
    var secretKey = builder.Configuration["AutoAuth:SecretKey"];

    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = builder.Configuration["AutoAuth:Issuer"] ?? "SimpleSmartMail",
        ValidAudience = builder.Configuration["AutoAuth:Audience"] ?? "leo.tutor.com",
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey)),
        ClockSkew = TimeSpan.FromMinutes(5) // Allow 5 min clock skew
    };
});

// Also keep your existing Cookie authentication
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.ExpireTimeSpan = TimeSpan.FromDays(7);
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.Run();
```

### Step 3: Configure appsettings.json

**File:** `leo.tutor.com/appsettings.json`

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

**⚠️ CRITICAL:** Use the **EXACT SAME** SecretKey, Issuer, and Audience values as SimpleSmartMail!

### Step 4: Create Auto-Login Controller

**File:** `leo.tutor.com/Controllers/OnDemandController.cs`

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace LeoTutor.Controllers;

public class OnDemandController : Controller
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<OnDemandController> _logger;
    // Inject your UserService or UserRepository
    private readonly IUserService _userService;

    public OnDemandController(
        IConfiguration configuration,
        ILogger<OnDemandController> logger,
        IUserService userService)
    {
        _configuration = configuration;
        _logger = logger;
        _userService = userService;
    }

    [HttpGet]
    public async Task<IActionResult> Index(string? token)
    {
        // If no token provided, show error or redirect to login
        if (string.IsNullOrEmpty(token))
        {
            _logger.LogWarning("OnDemand accessed without token");
            return RedirectToAction("Login", "Account");
        }

        try
        {
            // Validate and decode the JWT token
            var principal = ValidateToken(token);
            if (principal == null)
            {
                _logger.LogWarning("Invalid or expired token");
                TempData["Error"] = "This link has expired or is invalid. Please request a new one.";
                return RedirectToAction("Login", "Account");
            }

            // Extract user information from token
            var userId = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            var email = principal.FindFirst(ClaimTypes.Email)?.Value;
            var sessionId = principal.FindFirst("session_id")?.Value;

            if (string.IsNullOrEmpty(userId) || string.IsNullOrEmpty(email))
            {
                _logger.LogWarning("Token missing required claims");
                return RedirectToAction("Login", "Account");
            }

            // Verify user exists in your database
            var user = await _userService.GetUserByIdAsync(userId);
            if (user == null)
            {
                _logger.LogWarning("User {UserId} not found", userId);
                return RedirectToAction("Login", "Account");
            }

            // Create authentication cookie for the user
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim(ClaimTypes.Name, user.Name),
                new Claim(ClaimTypes.Role, user.Role) // If you use roles
            };

            var claimsIdentity = new ClaimsIdentity(
                claims,
                CookieAuthenticationDefaults.AuthenticationScheme);

            var authProperties = new AuthenticationProperties
            {
                IsPersistent = true, // Keep logged in
                ExpiresUtc = DateTimeOffset.UtcNow.AddDays(7)
            };

            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                new ClaimsPrincipal(claimsIdentity),
                authProperties);

            _logger.LogInformation("User {UserId} auto-authenticated via email link", userId);

            // Redirect to the tutoring page
            if (!string.IsNullOrEmpty(sessionId))
            {
                return RedirectToAction("Session", "Tutor", new { sessionId });
            }

            return RedirectToAction("Dashboard", "Tutor");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during auto-authentication");
            TempData["Error"] = "An error occurred. Please try logging in manually.";
            return RedirectToAction("Login", "Account");
        }
    }

    private ClaimsPrincipal? ValidateToken(string token)
    {
        var secretKey = _configuration["AutoAuth:SecretKey"];
        var issuer = _configuration["AutoAuth:Issuer"] ?? "SimpleSmartMail";
        var audience = _configuration["AutoAuth:Audience"] ?? "leo.tutor.com";

        var tokenHandler = new JwtSecurityTokenHandler();
        var key = Encoding.UTF8.GetBytes(secretKey);

        try
        {
            var principal = tokenHandler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = issuer,
                ValidAudience = audience,
                IssuerSigningKey = new SymmetricSecurityKey(key),
                ClockSkew = TimeSpan.FromMinutes(5)
            }, out SecurityToken validatedToken);

            // Check that purpose is auto-login
            var purposeClaim = principal.FindFirst("purpose")?.Value;
            if (purposeClaim != "auto-login")
            {
                _logger.LogWarning("Token has invalid purpose: {Purpose}", purposeClaim);
                return null;
            }

            return principal;
        }
        catch (SecurityTokenException ex)
        {
            _logger.LogWarning(ex, "Token validation failed");
            return null;
        }
    }
}
```

### Step 5: Alternative - Simpler Implementation Without JWT Library

If you want even simpler code without the JWT package:

```csharp
[HttpGet]
public async Task<IActionResult> Index(string? token, string? userId, string? timestamp, string? signature)
{
    // Simple HMAC-based authentication
    if (string.IsNullOrEmpty(userId) || string.IsNullOrEmpty(timestamp) || string.IsNullOrEmpty(signature))
    {
        return RedirectToAction("Login", "Account");
    }

    // Validate timestamp (link expires after 1 hour)
    if (!long.TryParse(timestamp, out long unixTimestamp))
        return RedirectToAction("Login", "Account");

    var linkTime = DateTimeOffset.FromUnixTimeSeconds(unixTimestamp);
    if (DateTimeOffset.UtcNow - linkTime > TimeSpan.FromHours(1))
    {
        TempData["Error"] = "This link has expired.";
        return RedirectToAction("Login", "Account");
    }

    // Validate signature
    var secretKey = _configuration["AutoAuth:SecretKey"];
    var computedSignature = ComputeHmacSha256($"{userId}:{timestamp}", secretKey);

    if (!signature.Equals(computedSignature, StringComparison.OrdinalIgnoreCase))
    {
        _logger.LogWarning("Invalid signature for user {UserId}", userId);
        return RedirectToAction("Login", "Account");
    }

    // Authenticate user...
    var user = await _userService.GetUserByIdAsync(userId);
    // ... rest of authentication
}

private string ComputeHmacSha256(string data, string key)
{
    using var hmac = new System.Security.Cryptography.HMACSHA256(Encoding.UTF8.GetBytes(key));
    var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(data));
    return Convert.ToBase64String(hash).Replace("+", "-").Replace("/", "_").Replace("=", "");
}
```

Then generate URLs like:
```
https://leo.tutor.com/ondemand?userId=alice123&timestamp=1638360000&signature=abc123def456
```

---

## Part 3: Security Considerations

### 1. Secret Key Management

**❌ DON'T:** Store secrets in appsettings.json in production

**✅ DO:** Use environment variables or Azure Key Vault

```bash
# Linux/Mac
export AutoAuth__SecretKey="your-production-secret-key-here"

# Windows
set AutoAuth__SecretKey=your-production-secret-key-here

# Or in production, use:
# - Azure Key Vault
# - AWS Secrets Manager
# - Docker secrets
```

### 2. Token Expiry

Set short expiry times (60 minutes recommended) to minimize risk if token is intercepted.

### 3. One-Time Use Tokens (Optional)

Track used tokens to prevent replay attacks:

```csharp
// Add to database
public class UsedToken
{
    public string TokenId { get; set; } // JTI claim
    public DateTime UsedAt { get; set; }
}

// Check before authenticating
var tokenId = principal.FindFirst(JwtRegisteredClaimNames.Jti)?.Value;
if (await _tokenRepository.IsTokenUsedAsync(tokenId))
{
    return RedirectToAction("Login", "Account");
}

await _tokenRepository.MarkTokenAsUsedAsync(tokenId);
```

### 4. HTTPS Only

**CRITICAL:** Only use auto-login URLs over HTTPS to prevent token interception.

### 5. Rate Limiting

Add rate limiting to prevent brute force attacks:

```csharp
// In Program.cs
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("autoLogin", opt =>
    {
        opt.Window = TimeSpan.FromMinutes(1);
        opt.PermitLimit = 5; // 5 attempts per minute
    });
});

// In controller
[EnableRateLimiting("autoLogin")]
public async Task<IActionResult> Index(string? token)
{
    // ...
}
```

---

## Part 4: Complete Example Flow

### Email Content (After Personalization)

```html
<html>
<body>
  <h1>Hi Alice</h1>
  <p>Your tutoring session is ready!</p>
  <p>
    <a href="https://leo.tutor.com/ondemand?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLWFsaWNlLTEyMyIsImVtYWlsIjoiYWxpY2VAZXhhbXBsZS5jb20iLCJqdGkiOiI3ODkwYWJjZCIsInB1cnBvc2UiOiJhdXRvLWxvZ2luIiwiaXNzIjoiU2ltcGxlU21hcnRNYWlsIiwiYXVkIjoibGVvLnR1dG9yLmNvbSIsImV4cCI6MTYzODM2MzYwMH0.abcd1234..."
       style="background: #4CAF50; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block;">
      Connect to Tutor Now
    </a>
  </p>
</body>
</html>
```

### What Happens When User Clicks

1. **User clicks** → Browser navigates to `https://leo.tutor.com/ondemand?token=eyJ...`

2. **OnDemandController.Index()** receives request

3. **Token validated**:
   - Signature verified
   - Expiry checked
   - Claims extracted (userId, email)

4. **User lookup**: Verify user exists in database

5. **Authentication**: Cookie created and user signed in

6. **Redirect**: User redirected to `/Tutor/Dashboard` (already authenticated!)

7. **Subsequent requests**: User stays logged in via cookie

---

## Part 5: Testing

### Test Token Generation

```csharp
// In SimpleSmartMail or test project
var service = new AutoAuthTokenService(configuration);
var token = service.GenerateAutoLoginToken(
    userId: "test-user-123",
    email: "test@example.com"
);

Console.WriteLine($"Generated Token: {token}");
Console.WriteLine($"URL: https://leo.tutor.com/ondemand?token={token}");

// Decode to verify claims (use jwt.io)
```

### Test on leo.tutor.com

```bash
# Visit this URL in browser
https://leo.tutor.com/ondemand?token=eyJhbGc...

# Should:
# 1. Validate token
# 2. Authenticate user
# 3. Redirect to dashboard
# 4. User is logged in!
```

---

## Summary

### SimpleSmartMail Side
1. ✅ Install JWT package
2. ✅ Create `AutoAuthTokenService`
3. ✅ Configure `AutoAuth:SecretKey` in appsettings.json
4. ✅ Generate tokens and add to PersonalizationData
5. ✅ Emails contain `{{TutorConnectUrl}}` with secure tokens

### leo.tutor.com Side
1. ✅ Install JWT package
2. ✅ Configure JWT authentication in Program.cs
3. ✅ Use **SAME** `AutoAuth:SecretKey` as SimpleSmartMail
4. ✅ Create `OnDemandController` to validate tokens
5. ✅ Authenticate user and create session cookie
6. ✅ Redirect to protected page

**Result:** Users click email link → Instantly logged in → Taken to tutoring page!
