namespace SimpleSmartMail.Models.Entities;

public class EmailCampaignProgram
{
    public int EmailCampaignId { get; set; }
    public int ProgramId { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public string CreatedBy { get; set; } = string.Empty;
    public string? UpdatedBy { get; set; }
}
