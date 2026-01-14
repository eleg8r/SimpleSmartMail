using SimpleSmartMail.Models.DTOs;
using SimpleSmartMail.Models.Entities;
using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Business.Services;

public interface IEmailService
{
    Task<SendEmailResponse> SendEmailAsync(SendEmailRequest request);
    Task<Email?> GetEmailByIdAsync(int id);
    Task<Email?> GetEmailByTrackingIdAsync(Guid trackingId);
    Task<List<Email>> GetAllEmailsAsync(int pageNumber = 1, int pageSize = 50);
}
