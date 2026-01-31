using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace SimpleSmartMail.Business.Services;

/// <summary>
/// Service for generating JWT-based auto-authentication tokens
/// Used to create secure one-time login links in emails
/// </summary>
public class AutoAuthTokenService : IAutoAuthTokenService
{
    private readonly IConfiguration configuration;

    public AutoAuthTokenService(IConfiguration configuration)
    {
        this.configuration = configuration;
    }

    public string GenerateAutoLoginToken(
        string userId,
        string email,
        string? sessionId = null,
        Dictionary<string, string>? additionalClaims = null)
    {
        // Validate configuration
        var secretKey = this.configuration["AutoAuth:SecretKey"];
        if (string.IsNullOrEmpty(secretKey))
        {
            throw new InvalidOperationException(
                "AutoAuth:SecretKey is not configured. Please add it to appsettings.json");
        }

        if (secretKey.Length < 32)
        {
            throw new InvalidOperationException(
                "AutoAuth:SecretKey must be at least 32 characters long for security");
        }

        var issuer = this.configuration["AutoAuth:Issuer"] ?? "SimpleSmartMail";
        var audience = this.configuration["AutoAuth:Audience"] ?? "leo.tutor.com";
        var expiryMinutes = this.configuration.GetValue<int>("AutoAuth:ExpiryMinutes", 60);

        // Create security key
        var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
        var credentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);

        // Build claims
        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, userId),
            new Claim(ClaimTypes.Email, email),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new Claim("purpose", "auto-login"),
            new Claim("generated_at", DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString())
        };

        // Add optional session ID
        if (!string.IsNullOrEmpty(sessionId))
        {
            claims.Add(new Claim("session_id", sessionId));
        }

        // Add any additional custom claims
        if (additionalClaims != null)
        {
            foreach (var claim in additionalClaims)
            {
                claims.Add(new Claim(claim.Key, claim.Value));
            }
        }

        // Create JWT token
        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(expiryMinutes),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public string GenerateTutorConnectUrl(
        string userId,
        string email,
        string baseUrl,
        string? sessionId = null)
    {
        // Ensure baseUrl doesn't end with slash
        baseUrl = baseUrl.TrimEnd('/');

        // Generate token
        var token = GenerateAutoLoginToken(userId, email, sessionId);

        // Build URL
        var url = $"{baseUrl}/ondemand?token={token}";

        // Add session ID as backup query parameter if provided
        if (!string.IsNullOrEmpty(sessionId))
        {
            url += $"&sessionId={sessionId}";
        }

        return url;
    }
}
