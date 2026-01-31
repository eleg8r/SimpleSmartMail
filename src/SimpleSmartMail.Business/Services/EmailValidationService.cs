using System.Net;
using System.Net.Mail;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

namespace SimpleSmartMail.Business.Services;

public class EmailValidationService : IEmailValidationService
{
    private readonly ILogger<EmailValidationService> logger;

    // RFC 5322 compliant email regex (simplified)
    private static readonly Regex EmailRegex = new Regex(
        @"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    public EmailValidationService(ILogger<EmailValidationService> logger)
    {
        this.logger = logger;
    }

    public async Task<EmailValidationResult> ValidateEmailAsync(string emailAddress, bool checkDomain = false)
    {
        if (string.IsNullOrWhiteSpace(emailAddress))
        {
            return EmailValidationResult.Invalid(emailAddress, "Email address is required");
        }

        // Trim whitespace
        emailAddress = emailAddress.Trim();

        // 1. Basic format validation
        var formatValidation = ValidateFormat(emailAddress);
        if (!formatValidation.IsValid)
        {
            return formatValidation;
        }

        // 2. Domain validation (if enabled)
        if (checkDomain)
        {
            var domainValidation = await ValidateDomainAsync(emailAddress);
            if (!domainValidation.IsValid)
            {
                return domainValidation;
            }
        }

        return EmailValidationResult.Valid(emailAddress, checkDomain ? "Domain" : "Format");
    }

    public async Task<Dictionary<string, EmailValidationResult>> ValidateEmailsAsync(
        IEnumerable<string> emailAddresses,
        bool checkDomain = false)
    {
        var results = new Dictionary<string, EmailValidationResult>();

        foreach (var email in emailAddresses)
        {
            var result = await ValidateEmailAsync(email, checkDomain);
            results[email] = result;
        }

        return results;
    }

    private EmailValidationResult ValidateFormat(string emailAddress)
    {
        var errors = new List<string>();

        // Check length
        if (emailAddress.Length > 254)
        {
            errors.Add("Email address exceeds maximum length of 254 characters");
        }

        // Check for @ symbol
        if (!emailAddress.Contains('@'))
        {
            errors.Add("Email address must contain @ symbol");
        }
        else
        {
            var parts = emailAddress.Split('@');
            if (parts.Length != 2)
            {
                errors.Add("Email address must contain exactly one @ symbol");
            }
            else
            {
                var localPart = parts[0];
                var domainPart = parts[1];

                // Validate local part (before @)
                if (string.IsNullOrEmpty(localPart))
                {
                    errors.Add("Email address local part cannot be empty");
                }
                else if (localPart.Length > 64)
                {
                    errors.Add("Email address local part exceeds maximum length of 64 characters");
                }
                else if (localPart.StartsWith(".") || localPart.EndsWith("."))
                {
                    errors.Add("Email address local part cannot start or end with a dot");
                }
                else if (localPart.Contains(".."))
                {
                    errors.Add("Email address local part cannot contain consecutive dots");
                }

                // Validate domain part (after @)
                if (string.IsNullOrEmpty(domainPart))
                {
                    errors.Add("Email address domain cannot be empty");
                }
                else if (domainPart.Length > 253)
                {
                    errors.Add("Email address domain exceeds maximum length of 253 characters");
                }
                else if (domainPart.StartsWith("-") || domainPart.EndsWith("-"))
                {
                    errors.Add("Email address domain cannot start or end with hyphen");
                }
                else if (!domainPart.Contains('.'))
                {
                    errors.Add("Email address domain must contain at least one dot");
                }
            }
        }

        // Regex validation
        if (!EmailRegex.IsMatch(emailAddress))
        {
            errors.Add("Email address contains invalid characters");
        }

        // Try MailAddress constructor
        try
        {
            var mailAddress = new MailAddress(emailAddress);
            if (mailAddress.Address != emailAddress)
            {
                errors.Add("Email address format is invalid");
            }
        }
        catch (FormatException ex)
        {
            errors.Add($"Invalid email format: {ex.Message}");
        }

        if (errors.Any())
        {
            return EmailValidationResult.Invalid(emailAddress, errors.ToArray());
        }

        return EmailValidationResult.Valid(emailAddress, "Format");
    }

    private async Task<EmailValidationResult> ValidateDomainAsync(string emailAddress)
    {
        try
        {
            var domain = emailAddress.Split('@')[1];

            // Check if domain resolves
            var hostEntry = await Dns.GetHostEntryAsync(domain);

            if (hostEntry == null || hostEntry.AddressList.Length == 0)
            {
                return EmailValidationResult.Invalid(emailAddress, "Domain does not resolve to any IP address");
            }

            return EmailValidationResult.Valid(emailAddress, "Domain");
        }
        catch (Exception ex)
        {
            this.logger.LogWarning(ex, "Domain validation failed for {Email}", emailAddress);
            return EmailValidationResult.Invalid(emailAddress, $"Domain validation failed: {ex.Message}");
        }
    }
}
