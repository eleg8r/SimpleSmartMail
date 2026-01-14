using System.ComponentModel.DataAnnotations;

namespace SimpleSmartMail.Models.DTOs;

public class CreateCampaignRequest
{
    [Required]
    [MinLength(1, ErrorMessage = "At least one program must be specified")]
    public List<int> ProgramIds { get; set; } = new();

    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;

    [Required]
    [EmailAddress]
    public string FromAddress { get; set; } = string.Empty;

    [Required]
    public string FromName { get; set; } = string.Empty;

    [Required]
    [MaxLength(500)]
    public string Subject { get; set; } = string.Empty;

    [Required]
    public string HtmlTemplate { get; set; } = string.Empty;

    public string? TextTemplate { get; set; }
    public DateTime? ScheduledStartDate { get; set; }
    public int? BatchSize { get; set; }
    public int? MaxEmailsPerHour { get; set; }
    public bool EnableOpenTracking { get; set; } = true;
    public bool EnableClickTracking { get; set; } = true;
    public bool AutoGenerateAuthTokens { get; set; } = false;
    public string? AutoAuthBaseUrl { get; set; }
    public string? AutoAuthTokenKey { get; set; }

    [Required]
    [MinLength(1, ErrorMessage = "At least one recipient is required")]
    public List<CampaignRecipientDto> Recipients { get; set; } = new();

    public string CreatedBy { get; set; } = string.Empty;
}

public class CampaignRecipientDto
{
    [Required]
    [EmailAddress]
    public string EmailAddress { get; set; } = string.Empty;

    public string? RecipientName { get; set; }
    public string? UserId { get; set; }
    public Dictionary<string, string>? PersonalizationData { get; set; }
}
