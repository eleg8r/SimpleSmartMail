namespace SimpleSmartMail.Models.DTOs;

public class CreateCampaignRequest
{
    public string TenantId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string FromAddress { get; set; } = string.Empty;
    public string FromName { get; set; } = string.Empty;
    public string Subject { get; set; } = string.Empty;
    public string HtmlTemplate { get; set; } = string.Empty;
    public string? TextTemplate { get; set; }
    public DateTime? ScheduledStartDate { get; set; }
    public int? BatchSize { get; set; }
    public int? MaxEmailsPerHour { get; set; }
    public bool EnableOpenTracking { get; set; } = true;
    public bool EnableClickTracking { get; set; } = true;
    public List<CampaignRecipientDto> Recipients { get; set; } = new();
    public string CreatedBy { get; set; } = string.Empty;
}

public class CampaignRecipientDto
{
    public string EmailAddress { get; set; } = string.Empty;
    public string? RecipientName { get; set; }
    public Dictionary<string, string>? PersonalizationData { get; set; }
}
