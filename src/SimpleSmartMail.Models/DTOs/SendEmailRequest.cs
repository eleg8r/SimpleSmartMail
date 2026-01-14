using System.ComponentModel.DataAnnotations;

namespace SimpleSmartMail.Models.DTOs;

public class SendEmailRequest
{
    public int? ProgramId { get; set; } // Optional - for unsubscribe checks

    [Required(ErrorMessage = "From address is required")]
    [EmailAddress(ErrorMessage = "Invalid from email address")]
    public string FromAddress { get; set; } = string.Empty;

    public string FromName { get; set; } = string.Empty;

    [Required(ErrorMessage = "To address is required")]
    [EmailAddress(ErrorMessage = "Invalid to email address")]
    public string ToAddress { get; set; } = string.Empty;

    public string ToName { get; set; } = string.Empty;
    public List<string>? Cc { get; set; }
    public List<string>? Bcc { get; set; }

    [Required(ErrorMessage = "Subject is required")]
    [MaxLength(500, ErrorMessage = "Subject cannot exceed 500 characters")]
    public string Subject { get; set; } = string.Empty;

    [Required(ErrorMessage = "Email body is required")]
    public string HtmlBody { get; set; } = string.Empty;

    public string? TextBody { get; set; }
    public List<AttachmentDto>? Attachments { get; set; }
    public bool SendImmediately { get; set; } = true;
    public DateTime? ScheduledAt { get; set; }
    public bool EnableOpenTracking { get; set; } = true;
    public bool EnableClickTracking { get; set; } = true;
}

public class AttachmentDto
{
    [Required]
    public string FileName { get; set; } = string.Empty;

    [Required]
    public string ContentType { get; set; } = string.Empty;

    [Required]
    public byte[] Content { get; set; } = Array.Empty<byte>();
}
