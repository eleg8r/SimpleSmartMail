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
    /// Get all campaigns with pagination
    /// </summary>
    [HttpGet]
    public async Task<ActionResult> GetAllCampaigns([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 50)
    {
        try
        {
            var campaigns = await _campaignService.GetAllCampaignsAsync(pageNumber, pageSize);
            return Ok(new { PageNumber = pageNumber, PageSize = pageSize, Campaigns = campaigns });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving campaigns");
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

    /// <summary>
    /// Add a program to a campaign
    /// </summary>
    [HttpPost("{id}/programs/{programId}")]
    public async Task<ActionResult> AddProgramToCampaign(int id, int programId, [FromQuery] string createdBy = "System")
    {
        try
        {
            await _campaignService.AddProgramToCampaignAsync(id, programId, createdBy);
            return Ok(new { Message = "Program added to campaign successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding program {ProgramId} to campaign {CampaignId}", programId, id);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Remove a program from a campaign
    /// </summary>
    [HttpDelete("{id}/programs/{programId}")]
    public async Task<ActionResult> RemoveProgramFromCampaign(int id, int programId)
    {
        try
        {
            await _campaignService.RemoveProgramFromCampaignAsync(id, programId);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing program {ProgramId} from campaign {CampaignId}", programId, id);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Get all programs for a campaign
    /// </summary>
    [HttpGet("{id}/programs")]
    public async Task<ActionResult> GetCampaignPrograms(int id)
    {
        try
        {
            var programs = await _campaignService.GetCampaignProgramsAsync(id);
            return Ok(programs);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving programs for campaign {CampaignId}", id);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Get all campaigns for a specific program
    /// </summary>
    [HttpGet("programs/{programId}")]
    public async Task<ActionResult> GetCampaignsByProgram(int programId)
    {
        try
        {
            var campaigns = await _campaignService.GetCampaignsByProgramIdAsync(programId);
            return Ok(campaigns);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving campaigns for program {ProgramId}", programId);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }
}

public class UpdateCampaignStatusRequest
{
    public CampaignStatus Status { get; set; }
}
