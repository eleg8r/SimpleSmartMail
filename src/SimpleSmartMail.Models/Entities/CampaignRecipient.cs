namespace SimpleSmartMail.Models.Entities;

public class CampaignRecipient
{
    public int Id { get; set; }
    public int CampaignId { get; set; }
    public string EmailAddress { get; set; } = string.Empty;
    public string? RecipientName { get; set; }
    public string? PersonalizationData { get; set; }
    public int? EmailId { get; set; }
    public bool Sent { get; set; }
    public DateTime? SentAt { get; set; }
}
