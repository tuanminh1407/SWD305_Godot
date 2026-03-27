using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.Models;
using Microsoft.AspNetCore.Authorization;
using System.Text.Json;

namespace SWD305.Controllers
{
    [Authorize(Roles = "staff,admin")]
    [ApiController]
    [Route("api/staff/users")]
    public class StaffUserController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public StaffUserController(VnegSystemContext context)
        {
            _context = context;
        }

        // ── GET USERS (Filter + Paginate) ──
        [HttpGet]
        public async Task<IActionResult> GetUsers(
            [FromQuery] int? grade,
            [FromQuery] string? region,
            [FromQuery] bool? active,
            [FromQuery] string? search,
            [FromQuery] int page = 1,
            [FromQuery] int size = 20)
        {
            var query = _context.Users.AsQueryable();

            if (grade.HasValue)
                query = query.Where(u => u.Grade == grade.Value);
            if (!string.IsNullOrWhiteSpace(region))
                query = query.Where(u => u.Region == region);
            if (active.HasValue)
                query = query.Where(u => u.IsActive == active.Value);
            if (!string.IsNullOrWhiteSpace(search))
                query = query.Where(u => u.Email.Contains(search));

            var totalCount = await query.CountAsync();
            var totalPages = (int)Math.Ceiling(totalCount / (double)size);

            var users = await query
                .OrderByDescending(u => u.CreatedAt)
                .Skip((page - 1) * size)
                .Take(size)
                .Select(u => new
                {
                    u.Id,
                    u.Email,
                    u.Phone,
                    u.Grade,
                    u.Region,
                    u.Role,
                    u.IsActive,
                    u.CreatedAt
                })
                .ToListAsync();

            return Ok(new
            {
                users,
                pagination = new
                {
                    page,
                    size,
                    totalCount,
                    totalPages
                }
            });
        }

        // ── TOGGLE USER STATUS (Suspend / Ban / Unlock) ──
        [HttpPatch("{id:int}/status")]
        public async Task<IActionResult> ToggleStatus(int id, [FromBody] ToggleStatusDto dto)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound("User not found");

            var oldStatus = user.IsActive;
            user.IsActive = dto.IsActive;
            user.UpdatedAt = DateTime.Now;

            // Get staff user ID from claims
            var staffId = int.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "0");

            // Write audit log
            var log = new SystemLog
            {
                UserId = staffId,
                Action = "user_status_change",
                Details = JsonSerializer.Serialize(new
                {
                    targetUserId = id,
                    targetEmail = user.Email,
                    oldStatus = oldStatus,
                    newStatus = dto.IsActive,
                    reason = dto.Reason ?? "",
                    action = dto.ActionType ?? (dto.IsActive == true ? "unlock" : "suspend")
                }),
                CreatedAt = DateTime.Now
            };

            _context.SystemLogs.Add(log);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                user.Id,
                user.Email,
                user.IsActive,
                auditLogId = log.Id
            });
        }

        // ── GET USER AUDIT LOG ──
        [HttpGet("{id:int}/audit-log")]
        public async Task<IActionResult> GetUserAuditLog(int id)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound("User not found");

            // Get logs where this user was the target
            var logs = await _context.SystemLogs
                .Where(l => l.Details != null && l.Details.Contains($"\"targetUserId\":{id}"))
                .OrderByDescending(l => l.CreatedAt)
                .Take(50)
                .Select(l => new
                {
                    l.Id,
                    staffUserId = l.UserId,
                    l.Action,
                    l.Details,
                    l.CreatedAt
                })
                .ToListAsync();

            return Ok(new { userId = id, email = user.Email, logs });
        }
    }

    // DTO for toggle status
    public class ToggleStatusDto
    {
        public bool IsActive { get; set; }
        public string? Reason { get; set; }
        public string? ActionType { get; set; } // "suspend", "ban", "unlock"
    }
}
