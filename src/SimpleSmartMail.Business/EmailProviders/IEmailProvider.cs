using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Business.EmailProviders;

public interface IEmailProvider
{
    Task<bool> SendAsync(Email email, CancellationToken cancellationToken = default);
    Task<List<(bool Success, string ErrorMessage)>> SendBulkAsync(List<Email> emails, CancellationToken cancellationToken = default);
}
