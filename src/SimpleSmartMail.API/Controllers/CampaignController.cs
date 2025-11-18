using Microsoft.AspNetCore.Mvc;
using SimpleSmartMail.Business.Services;
using SimpleSmartMail.Models.DTOs;
using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CampaignController : ControllerBase
{
    private readonly ICampaignService _campaignService;
    private readonly ILogger<CampaignController> _logger;

    public CampaignController(ICampaignService campaignService, ILogger<CampaignController> logger)
    {
        _campaignService = campaignService;
        _logger = logger;
    }

    /// <summary>
    /// Create a new email campaign
    /// </summary>
    [HttpPost]
    public async Task<ActionResult> CreateCampaign([FromBody] CreateCampaignRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var campaignId = await _campaignService.CreateCampaignAsync(request);
            return CreatedAtAction(nameof(GetCampaign), new { id = campaignId }, new { Id = campaignId });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating campaign");
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Get campaign by ID
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult> GetCampaign(int id)
    {
        try
        {
            var campaign = await _campaignService.GetCampaignByIdAsync(id);

            if (campaign == null)
            {
                return NotFound(new { Message = $"Campaign with ID {id} not found" });
            }

            return Ok(campaign);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving campaign {CampaignId}", id);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Get all campaigns for a tenant
    /// </summary>
    [HttpGet("tenant/{tenantId}")]
    public async Task<ActionResult> GetCampaignsByTenant(string tenantId)
    {
        try
        {
            var campaigns = await _campaignService.GetCampaignsByTenantIdAsync(tenantId);
            return Ok(campaigns);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving campaigns for tenant {TenantId}", tenantId);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Start a campaign
    /// </summary>
    [HttpPost("{id}/start")]
    public async Task<ActionResult> StartCampaign(int id)
    {
        try
        {
            await _campaignService.StartCampaignAsync(id);
            return Ok(new { Message = "Campaign started successfully" });
        }
        catch (ArgumentException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error starting campaign {CampaignId}", id);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Update campaign status
    /// </summary>
    [HttpPut("{id}/status")]
    public async Task<ActionResult> UpdateCampaignStatus(int id, [FromBody] UpdateCampaignStatusRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            await _campaignService.UpdateCampaignStatusAsync(id, request.Status);
            return NoContent();
        }
        catch (ArgumentException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating campaign status {CampaignId}", id);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }
}

public class UpdateCampaignStatusRequest
{
    public CampaignStatus Status { get; set; }
}
