namespace SimpleSmartMail.Models.DTOs;

public class CreateTemplateRequest
{
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Subject { get; set; } = string.Empty;
    public string HtmlTemplate { get; set; } = string.Empty;
    public string? TextTemplate { get; set; }
    public string CreatedBy { get; set; } = string.Empty;
}
