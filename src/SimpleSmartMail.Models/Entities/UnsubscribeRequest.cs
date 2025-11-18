namespace SimpleSmartMail.Models.Entities;

public class UnsubscribeRequest
{
    public int Id { get; set; }
    public string TenantId { get; set; } = string.Empty;
    public string EmailAddress { get; set; } = string.Empty;
    public int? CampaignId { get; set; }
    public int? EmailId { get; set; }
    public Guid? TrackingId { get; set; }
    public DateTime UnsubscribedAt { get; set; }
    public string? Reason { get; set; }
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    public bool GlobalUnsubscribe { get; set; }
}
