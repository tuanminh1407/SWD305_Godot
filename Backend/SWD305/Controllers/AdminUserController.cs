using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.DTO;
using SWD305.Models;

using Microsoft.AspNetCore.Authorization;

namespace SWD305.Controllers
{
    [Authorize(Roles = "admin")]
    [ApiController]
    [Route("api/admin/users")]
    public class AdminUserController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public AdminUserController(VnegSystemContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var users = await _context.Users
                .OrderByDescending(u => u.CreatedAt)
                .Select(u => new
                {
                    u.Id,
                    u.Email,
                    u.Phone,
                    u.AvatarUrl,
                    u.Grade,
                    u.Region,
                    u.Role,
                    u.IsActive,
                    u.CreatedAt,
                    u.UpdatedAt
                })
                .ToListAsync();

            return Ok(users);
        }

        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetById(int id)
        {
            var user = await _context.Users
                .Where(u => u.Id == id)
                .Select(u => new
                {
                    u.Id,
                    u.Email,
                    u.Phone,
                    u.AvatarUrl,
                    u.Grade,
                    u.Region,
                    u.Role,
                    u.IsActive,
                    u.CreatedAt,
                    u.UpdatedAt
                })
                .FirstOrDefaultAsync();

            if (user == null) return NotFound("User not found");
            return Ok(user);
        }

        [HttpPatch("{id:int}/active")]
        public async Task<IActionResult> SetActive(int id, UpdateUserActiveDto dto)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound("User not found");

            user.IsActive = dto.IsActive;
            user.UpdatedAt = DateTime.Now;
            await _context.SaveChangesAsync();

            return Ok(new { user.Id, user.IsActive });
        }

        [HttpPatch("{id:int}/role")]
        public async Task<IActionResult> SetRole(int id, UpdateUserRoleDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Role))
                return BadRequest("Role is required.");

            var normalizedRole = dto.Role.Trim().ToLowerInvariant();
            if (normalizedRole is not ("admin" or "staff" or "user"))
                return BadRequest("Role must be 'admin', 'staff', or 'user'.");

            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound("User not found");

            user.Role = normalizedRole;
            user.UpdatedAt = DateTime.Now;
            await _context.SaveChangesAsync();

            return Ok(new { user.Id, user.Role });
        }
    }
}

