namespace SimpleSmartMail.Models.DTOs;

public class SendEmailResponse
{
    public bool Success { get; set; }
    public int EmailId { get; set; }
    public Guid TrackingId { get; set; }
    public string? ErrorMessage { get; set; }
}
