using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Models.Entities;

public class EmailCampaign
{
    public int Id { get; set; }
    public string TenantId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public CampaignStatus Status { get; set; }
    public string FromAddress { get; set; } = string.Empty;
    public string FromName { get; set; } = string.Empty;
    public string Subject { get; set; } = string.Empty;
    public string HtmlTemplate { get; set; } = string.Empty;
    public string? TextTemplate { get; set; }
    public DateTime? ScheduledStartDate { get; set; }
    public int? BatchSize { get; set; }
    public int? MaxEmailsPerHour { get; set; }
    public bool EnableOpenTracking { get; set; }
    public bool EnableClickTracking { get; set; }
    public int TotalRecipients { get; set; }
    public int EmailsSent { get; set; }
    public int EmailsDelivered { get; set; }
    public int EmailsOpened { get; set; }
    public int EmailsClicked { get; set; }
    public int EmailsFailed { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string CreatedBy { get; set; } = string.Empty;
    public string? UpdatedBy { get; set; }

    public List<CampaignRecipient> Recipients { get; set; } = new();
}
