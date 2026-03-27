using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.DTO;
using SWD305.Models;
using SWD305.Security;

namespace SWD305.Controllers
{
    [ApiController]
    [Route("api/users")]
    public class UserController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public UserController(VnegSystemContext context)
        {
            _context = context;
        }

        private static string GenerateToken()
        {
            // 32 bytes -> 43/44 chars base64url; stored as string in DB
            var bytes = RandomNumberGenerator.GetBytes(32);
            return Convert.ToBase64String(bytes)
                .Replace('+', '-')
                .Replace('/', '_')
                .TrimEnd('=');
        }

        private async Task<(User user, Session session)?> GetUserByToken(string token)
        {
            if (string.IsNullOrWhiteSpace(token)) return null;

            var now = DateTime.Now;
            var session = await _context.Sessions
                .Include(s => s.User)
                .FirstOrDefaultAsync(s => s.JwtToken == token && s.ExpiresAt > now);

            if (session?.User == null) return null;
            if (session.User.IsActive == false) return null;

            return (session.User, session);
        }

        // =============================
        // REGISTER
        // =============================
        [HttpPost("register")]
        public async Task<IActionResult> Register(RegisterUserDto dto)
        {
            var email = dto.Email?.Trim().ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(email)) return BadRequest("Email is required.");
            if (string.IsNullOrWhiteSpace(dto.Password)) return BadRequest("Password is required.");

            var exists = await _context.Users.AnyAsync(u => u.Email == email);
            if (exists) return BadRequest("Email already exists.");

            // NOTE: Your DB has a CHECK constraint on users.region.
            // To avoid 500s during demo, we only persist region when provided and looks safe.
            // If the value violates DB constraints, we return a 400 instead of crashing.
            var region = string.IsNullOrWhiteSpace(dto.Region) ? null : dto.Region.Trim();

            var user = new User
            {
                Email = email,
                Phone = dto.Phone,
                Grade = dto.Grade,
                Region = region,
                AvatarUrl = dto.AvatarUrl,
                Role = "user",
                IsActive = true,
                PasswordHash = PasswordHashing.HashPassword(dto.Password),
                CreatedAt = DateTime.Now,
                UpdatedAt = DateTime.Now
            };

            _context.Users.Add(user);
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException ex)
            {
                return BadRequest(new
                {
                    message = "Invalid user data for database constraints.",
                    detail = ex.InnerException?.Message ?? ex.Message
                });
            }

            // create profile if your flow expects it
            var profile = new Profile { UserId = user.Id };
            _context.Profiles.Add(profile);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                user.Id,
                user.Email,
                user.Phone,
                user.AvatarUrl,
                user.Grade,
                user.Region,
                user.Role,
                user.IsActive,
                user.CreatedAt
            });
        }

        // =============================
        // LOGIN (CREATE SESSION TOKEN)
        // =============================
        [HttpPost("login")]
        public async Task<IActionResult> Login(LoginUserDto dto)
        {
            var email = dto.Email?.Trim().ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(email)) return BadRequest("Email is required.");
            if (string.IsNullOrWhiteSpace(dto.Password)) return BadRequest("Password is required.");

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null) return Unauthorized("Invalid email or password.");
            if (user.IsActive == false) return Unauthorized("User is inactive.");

            var ok = PasswordHashing.VerifyPassword(dto.Password, user.PasswordHash);
            if (!ok) return Unauthorized("Invalid email or password.");

            var token = GenerateToken();
            var session = new Session
            {
                UserId = user.Id,
                JwtToken = token,
                ExpiresAt = DateTime.Now.AddDays(7)
            };

            _context.Sessions.Add(session);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                token,
                sessionId = session.Id,
                expiresAt = session.ExpiresAt,
                user = new
                {
                    user.Id,
                    user.Email,
                    user.Phone,
                    user.AvatarUrl,
                    user.Grade,
                    user.Region,
                    user.Role,
                    user.IsActive
                }
            });
        }

        // =============================
        // ME (TOKEN VIA HEADER: X-Session-Token)
        // =============================
        [HttpGet("me")]
        public async Task<IActionResult> Me([FromHeader(Name = "X-Session-Token")] string token)
        {
            var result = await GetUserByToken(token);
            if (result == null) return Unauthorized("Invalid or expired token.");

            var (user, session) = result.Value;
            return Ok(new
            {
                sessionId = session.Id,
                sessionExpiresAt = session.ExpiresAt,
                user = new
                {
                    user.Id,
                    user.Email,
                    user.Phone,
                    user.AvatarUrl,
                    user.Grade,
                    user.Region,
                    user.Role,
                    user.IsActive,
                    user.CreatedAt,
                    user.UpdatedAt
                }
            });
        }

        [HttpPut("me")]
        public async Task<IActionResult> UpdateMe([FromHeader(Name = "X-Session-Token")] string token, UpdateMeDto dto)
        {
            var result = await GetUserByToken(token);
            if (result == null) return Unauthorized("Invalid or expired token.");

            var (user, _) = result.Value;

            user.Phone = dto.Phone ?? user.Phone;
            user.Grade = dto.Grade ?? user.Grade;
            if (dto.Region != null)
            {
                user.Region = string.IsNullOrWhiteSpace(dto.Region) ? null : dto.Region.Trim();
            }
            user.AvatarUrl = dto.AvatarUrl ?? user.AvatarUrl;
            user.UpdatedAt = DateTime.Now;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException ex)
            {
                return BadRequest(new
                {
                    message = "Invalid update for database constraints.",
                    detail = ex.InnerException?.Message ?? ex.Message
                });
            }

            return Ok(new
            {
                user.Id,
                user.Email,
                user.Phone,
                user.AvatarUrl,
                user.Grade,
                user.Region,
                user.Role,
                user.IsActive,
                user.UpdatedAt
            });
        }

        [HttpPost("me/change-password")]
        public async Task<IActionResult> ChangePassword(
            [FromHeader(Name = "X-Session-Token")] string token,
            ChangePasswordDto dto)
        {
            var result = await GetUserByToken(token);
            if (result == null) return Unauthorized("Invalid or expired token.");

            var (user, _) = result.Value;

            if (!PasswordHashing.VerifyPassword(dto.CurrentPassword, user.PasswordHash))
                return Unauthorized("Current password is incorrect.");

            if (string.IsNullOrWhiteSpace(dto.NewPassword))
                return BadRequest("NewPassword is required.");

            user.PasswordHash = PasswordHashing.HashPassword(dto.NewPassword);
            user.UpdatedAt = DateTime.Now;
            await _context.SaveChangesAsync();

            return Ok("Password changed successfully");
        }

        // =============================
        // LOGOUT (DELETE SESSION)
        // =============================
        [HttpPost("logout")]
        public async Task<IActionResult> Logout(LogoutDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Token))
                return BadRequest("Token is required.");

            var session = await _context.Sessions.FirstOrDefaultAsync(s => s.JwtToken == dto.Token);
            if (session == null) return Ok("Logged out");

            _context.Sessions.Remove(session);
            await _context.SaveChangesAsync();

            return Ok("Logged out");
        }

        // =============================
        // PUBLIC USER LOOKUP (SANITIZED)
        // =============================
        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetUserById(int id)
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
        [HttpGet("search")]
        public async Task<IActionResult> Search([FromQuery] string q)
        {
            if (string.IsNullOrWhiteSpace(q) || q.Length < 3)
                return BadRequest("Search query must be at least 3 characters.");

            var users = await _context.Users
                .Where(u => u.IsActive == true && u.Email.Contains(q))
                .Take(10)
                .Select(u => new
                {
                    u.Id,
                    u.Email,
                    u.AvatarUrl
                })
                .ToListAsync();

            return Ok(users);
        }
    }
}

