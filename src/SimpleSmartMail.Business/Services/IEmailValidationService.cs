namespace SimpleSmartMail.Business.Services;

public interface IEmailValidationService
{
    /// <summary>
    /// Validates email address format and optionally checks domain
    /// </summary>
    Task<EmailValidationResult> ValidateEmailAsync(string emailAddress, bool checkDomain = false);

    /// <summary>
    /// Validates multiple email addresses
    /// </summary>
    Task<Dictionary<string, EmailValidationResult>> ValidateEmailsAsync(IEnumerable<string> emailAddresses, bool checkDomain = false);
}

public class EmailValidationResult
{
    public bool IsValid { get; set; }
    public string EmailAddress { get; set; } = string.Empty;
    public List<string> Errors { get; set; } = new();
    public string? ValidationLevel { get; set; } // "Format", "Domain", "MX"

    public static EmailValidationResult Valid(string email, string level = "Format")
    {
        return new EmailValidationResult
        {
            IsValid = true,
            EmailAddress = email,
            ValidationLevel = level
        };
    }

    public static EmailValidationResult Invalid(string email, params string[] errors)
    {
        return new EmailValidationResult
        {
            IsValid = false,
            EmailAddress = email,
            Errors = errors.ToList()
        };
    }
}
