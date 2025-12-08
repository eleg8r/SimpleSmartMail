namespace SimpleSmartMail.Business.Services;

/// <summary>
/// Service for generating auto-authentication tokens for email links
/// </summary>
public interface IAutoAuthTokenService
{
    /// <summary>
    /// Generate a JWT token for auto-login
    /// </summary>
    /// <param name="userId">User identifier</param>
    /// <param name="email">User email address</param>
    /// <param name="sessionId">Optional session ID for direct session access</param>
    /// <param name="additionalClaims">Additional claims to include in token</param>
    /// <returns>JWT token string</returns>
    string GenerateAutoLoginToken(
        string userId,
        string email,
        string? sessionId = null,
        Dictionary<string, string>? additionalClaims = null);

    /// <summary>
    /// Generate a complete auto-login URL for tutor connection
    /// </summary>
    /// <param name="userId">User identifier</param>
    /// <param name="email">User email address</param>
    /// <param name="baseUrl">Base URL of the target website (e.g., https://leo.tutor.com)</param>
    /// <param name="sessionId">Optional session ID</param>
    /// <returns>Complete URL with embedded token</returns>
    string GenerateTutorConnectUrl(
        string userId,
        string email,
        string baseUrl,
        string? sessionId = null);
}
