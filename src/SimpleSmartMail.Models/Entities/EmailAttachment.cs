namespace SimpleSmartMail.Models.Entities;

public class EmailAttachment
{
    public int Id { get; set; }
    public int EmailId { get; set; }
    public string FileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long SizeInBytes { get; set; }
    public byte[] Content { get; set; } = Array.Empty<byte>();
}
