namespace SimpleSmartMail.Models.Entities;

public class UnsubscribeRequest
{
    public int Id { get; set; }
    public string EmailAddress { get; set; } = string.Empty;
    public int? ProgramId { get; set; } // NULL = global unsubscribe
    public int? CampaignId { get; set; }
    public int? EmailId { get; set; }
    public Guid? TrackingId { get; set; }
    public DateTime UnsubscribedAt { get; set; }
    public string? Reason { get; set; }
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
}
