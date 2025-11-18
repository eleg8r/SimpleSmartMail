using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Models.Entities;

public class Tenant
{
    public int Id { get; set; }
    public string TenantId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public EmailProviderType DefaultEmailProvider { get; set; }
    public int MaxAttachmentSizeInMb { get; set; }
    public int? MaxEmailsPerHour { get; set; }
    public int? MaxEmailsPerDay { get; set; }
    public bool EnableOpenTracking { get; set; }
    public bool EnableClickTracking { get; set; }
    public string? ApiKey { get; set; }
    public DateTime? ApiKeyCreatedAt { get; set; }
    public DateTime? ApiKeyExpiresAt { get; set; }
    public string? ContactEmail { get; set; }
    public string? ContactName { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}
