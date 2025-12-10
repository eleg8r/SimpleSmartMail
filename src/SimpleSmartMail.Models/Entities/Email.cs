using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Models.Entities;

public class Email
{
    public int Id { get; set; }
    public string TenantId { get; set; } = string.Empty;
    public string FromAddress { get; set; } = string.Empty;
    public string FromName { get; set; } = string.Empty;
    public string ToAddress { get; set; } = string.Empty;
    public string ToName { get; set; } = string.Empty;
    public string? Cc { get; set; }
    public string? Bcc { get; set; }
    public string Subject { get; set; } = string.Empty;
    public string HtmlBody { get; set; } = string.Empty;
    public string? TextBody { get; set; }
    public EmailStatus Status { get; set; }
    public int? CampaignId { get; set; }
    public Guid TrackingId { get; set; }
    public bool OpenTracked { get; set; }
    public DateTime? OpenedAt { get; set; }
    public int OpenCount { get; set; }
    public bool ClickTracked { get; set; }
    public DateTime? FirstClickedAt { get; set; }
    public int ClickCount { get; set; }
    public DateTime? ScheduledAt { get; set; }
    public DateTime? SentAt { get; set; }
    public DateTime? DeliveredAt { get; set; }
    public string? ErrorMessage { get; set; }
    public int RetryCount { get; set; }
    public bool IsValid { get; set; } = true;
    public string? ProviderUsed { get; set; }
    public string? Metadata { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }

    public List<EmailAttachment> Attachments { get; set; } = new();
}
