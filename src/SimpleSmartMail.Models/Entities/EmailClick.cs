namespace SimpleSmartMail.Models.Entities;

public class EmailClick
{
    public int Id { get; set; }
    public string TenantId { get; set; } = string.Empty;
    public int EmailId { get; set; }
    public int? CampaignId { get; set; }
    public Guid TrackingId { get; set; }
    public string RecipientEmail { get; set; } = string.Empty;
    public string OriginalUrl { get; set; } = string.Empty;
    public string TrackedUrl { get; set; } = string.Empty;
    public DateTime ClickedAt { get; set; }
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    public string? Country { get; set; }
    public string? City { get; set; }
    public string? Device { get; set; }
}
