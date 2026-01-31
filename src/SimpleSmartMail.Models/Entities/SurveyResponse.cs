namespace SimpleSmartMail.Models.Entities;

public class SurveyResponse
{
    public int Id { get; set; }
    public int EmailId { get; set; }
    public int? CampaignId { get; set; }
    public Guid TrackingId { get; set; }
    public string RecipientEmail { get; set; } = string.Empty;
    public string QuestionId { get; set; } = string.Empty;
    public string AnswerId { get; set; } = string.Empty;
    public string? AnswerText { get; set; }
    public DateTime RespondedAt { get; set; }
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
}
