using Microsoft.AspNetCore.Mvc;
using SimpleSmartMail.Business.Services;
using SimpleSmartMail.Models.DTOs;

namespace SimpleSmartMail.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class EmailController : ControllerBase
{
    private readonly IEmailService _emailService;
    private readonly ILogger<EmailController> _logger;

    public EmailController(IEmailService emailService, ILogger<EmailController> logger)
    {
        _emailService = emailService;
        _logger = logger;
    }

    /// <summary>
    /// Send an email
    /// </summary>
    [HttpPost("send")]
    public async Task<ActionResult<SendEmailResponse>> SendEmail([FromBody] SendEmailRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var result = await _emailService.SendEmailAsync(request);

            if (result.Success)
            {
                return Ok(result);
            }

            return StatusCode(500, result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending email");
            return StatusCode(500, new SendEmailResponse
            {
                Success = false,
                ErrorMessage = "Internal server error"
            });
        }
    }

    /// <summary>
    /// Get email by ID
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult> GetEmail(int id)
    {
        try
        {
            var email = await _emailService.GetEmailByIdAsync(id);

            if (email == null)
            {
                return NotFound(new { Message = $"Email with ID {id} not found" });
            }

            return Ok(email);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving email {EmailId}", id);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Get email by tracking ID
    /// </summary>
    [HttpGet("tracking/{trackingId}")]
    public async Task<ActionResult> GetEmailByTrackingId(Guid trackingId)
    {
        try
        {
            var email = await _emailService.GetEmailByTrackingIdAsync(trackingId);

            if (email == null)
            {
                return NotFound(new { Message = $"Email with tracking ID {trackingId} not found" });
            }

            return Ok(email);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving email by tracking ID {TrackingId}", trackingId);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Get all emails with pagination
    /// </summary>
    [HttpGet]
    public async Task<ActionResult> GetAllEmails([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 50)
    {
        try
        {
            var emails = await _emailService.GetAllEmailsAsync(pageNumber, pageSize);
            return Ok(new { PageNumber = pageNumber, PageSize = pageSize, Emails = emails });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving emails");
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }
}
