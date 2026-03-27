using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.Models;
using Microsoft.AspNetCore.Authorization;
using System.Text.Json;

namespace SWD305.Controllers
{
    [Authorize(Roles = "staff,admin")]
    [ApiController]
    [Route("api/staff/reports")]
    public class StaffReportController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public StaffReportController(VnegSystemContext context)
        {
            _context = context;
        }

        // ── GET REPORTS QUEUE ──
        [HttpGet]
        public async Task<IActionResult> GetReports(
            [FromQuery] string? status,
            [FromQuery] int page = 1,
            [FromQuery] int size = 20)
        {
            var query = _context.Reports
                .Include(r => r.User)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(status))
                query = query.Where(r => r.Status == status);

            var totalCount = await query.CountAsync();

            var reports = await query
                .OrderByDescending(r => r.Id)
                .Skip((page - 1) * size)
                .Take(size)
                .Select(r => new
                {
                    r.Id,
                    r.UserId,
                    userEmail = r.User != null ? r.User.Email : null,
                    r.Type,
                    r.Description,
                    r.Status,
                    r.ResolvedBy,
                    r.ResolvedAt
                })
                .ToListAsync();

            return Ok(new
            {
                reports,
                pagination = new
                {
                    page,
                    size,
                    totalCount,
                    totalPages = (int)Math.Ceiling(totalCount / (double)size)
                }
            });
        }

        // ── GET REPORT DETAIL ──
        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetReportDetail(int id)
        {
            var report = await _context.Reports
                .Include(r => r.User)
                .Where(r => r.Id == id)
                .Select(r => new
                {
                    r.Id,
                    r.UserId,
                    user = r.User != null ? new
                    {
                        r.User.Id,
                        r.User.Email,
                        r.User.Grade,
                        r.User.Region,
                        r.User.Role,
                        r.User.IsActive
                    } : null,
                    r.Type,
                    r.Description,
                    r.Status,
                    r.ResolvedBy,
                    r.ResolvedAt
                })
                .FirstOrDefaultAsync();

            if (report == null) return NotFound("Report not found");

            // Get user's recent game errors if user exists
            object? recentErrors = null;
            if (report.UserId.HasValue)
            {
                recentErrors = await _context.GameSessions
                    .Where(gs => gs.UserId == report.UserId.Value)
                    .OrderByDescending(gs => gs.CompletedAt)
                    .Take(5)
                    .Select(gs => new
                    {
                        gs.Id,
                        gs.GameId,
                        gameName = gs.Game.Name,
                        gs.Score,
                        gs.Accuracy,
                        gs.CompletedAt,
                        errorCount = gs.GameErrors.Count
                    })
                    .ToListAsync();
            }

            return Ok(new { report, recentGameSessions = recentErrors });
        }

        // ── RESOLVE REPORT ──
        [HttpPatch("{id:int}/resolve")]
        public async Task<IActionResult> ResolveReport(int id, [FromBody] ResolveReportDto dto)
        {
            var report = await _context.Reports
                .Include(r => r.User)
                .FirstOrDefaultAsync(r => r.Id == id);

            if (report == null) return NotFound("Report not found");

            var staffId = int.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "0");

            // Update report
            report.Status = dto.Status ?? "resolved";
            report.ResolvedBy = staffId;
            report.ResolvedAt = DateTime.Now;

            // Take action on user if specified
            if (dto.Action == "ban" && report.User != null)
            {
                report.User.IsActive = false;
                report.User.UpdatedAt = DateTime.Now;
            }

            // Write audit log
            var log = new SystemLog
            {
                UserId = staffId,
                Action = "report_resolved",
                Details = JsonSerializer.Serialize(new
                {
                    reportId = id,
                    targetUserId = report.UserId,
                    action = dto.Action,
                    reason = dto.Reason ?? "",
                    status = dto.Status ?? "resolved"
                }),
                CreatedAt = DateTime.Now
            };

            _context.SystemLogs.Add(log);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                report.Id,
                report.Status,
                report.ResolvedBy,
                report.ResolvedAt,
                actionTaken = dto.Action
            });
        }
    }

    // DTO for resolve
    public class ResolveReportDto
    {
        public string? Status { get; set; }   // "resolved", "dismissed"
        public string? Action { get; set; }   // "warn", "ban", "dismiss"
        public string? Reason { get; set; }
    }
}
