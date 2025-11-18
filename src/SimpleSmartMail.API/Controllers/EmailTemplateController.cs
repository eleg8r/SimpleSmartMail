using Microsoft.AspNetCore.Mvc;
using SimpleSmartMail.Business.Services;
using SimpleSmartMail.Models.DTOs;
using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class EmailTemplateController : ControllerBase
{
    private readonly IEmailTemplateService _templateService;
    private readonly ILogger<EmailTemplateController> _logger;

    public EmailTemplateController(IEmailTemplateService templateService, ILogger<EmailTemplateController> logger)
    {
        _templateService = templateService;
        _logger = logger;
    }

    /// <summary>
    /// Create a new email template
    /// </summary>
    [HttpPost]
    public async Task<ActionResult> CreateTemplate([FromBody] CreateTemplateRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var templateId = await _templateService.CreateTemplateAsync(request);
            return CreatedAtAction(nameof(GetTemplate), new { id = templateId }, new { Id = templateId });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating email template");
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Get email template by ID
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<EmailTemplate>> GetTemplate(int id)
    {
        try
        {
            var template = await _templateService.GetTemplateByIdAsync(id);

            if (template == null)
            {
                return NotFound(new { Message = $"Template with ID {id} not found" });
            }

            return Ok(template);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving template {TemplateId}", id);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Get all templates for a tenant
    /// </summary>
    [HttpGet("tenant/{tenantId}")]
    public async Task<ActionResult<List<EmailTemplate>>> GetTemplatesByTenant(string tenantId)
    {
        try
        {
            var templates = await _templateService.GetTemplatesByTenantIdAsync(tenantId);
            return Ok(templates);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving templates for tenant {TenantId}", tenantId);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Update an email template
    /// </summary>
    [HttpPut("{id}")]
    public async Task<ActionResult> UpdateTemplate(int id, [FromBody] EmailTemplate template)
    {
        if (id != template.Id)
        {
            return BadRequest(new { Message = "ID mismatch" });
        }

        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var existingTemplate = await _templateService.GetTemplateByIdAsync(id);
            if (existingTemplate == null)
            {
                return NotFound(new { Message = $"Template with ID {id} not found" });
            }

            await _templateService.UpdateTemplateAsync(template);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating template {TemplateId}", id);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Delete an email template
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<ActionResult> DeleteTemplate(int id)
    {
        try
        {
            var template = await _templateService.GetTemplateByIdAsync(id);
            if (template == null)
            {
                return NotFound(new { Message = $"Template with ID {id} not found" });
            }

            await _templateService.DeleteTemplateAsync(id);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting template {TemplateId}", id);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }
}
