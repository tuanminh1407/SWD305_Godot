using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.DTO;
using SWD305.Models;
using SWD305.Security;

namespace SWD305.Controllers
{
    [ApiController]
    [Route("api/teams")]
    public class TeamController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public TeamController(VnegSystemContext context)
        {
            _context = context;
        }

        private static string GenerateInviteCode()
        {
            // 9 bytes -> 12 chars base64-ish; make URL-safe
            var bytes = RandomNumberGenerator.GetBytes(9);
            return Convert.ToBase64String(bytes)
                .Replace('+', '-')
                .Replace('/', '_')
                .TrimEnd('=');
        }

        // Auth via header token for demo
        private async Task<User?> GetMe()
        {
            var token = Request.Headers["X-Session-Token"].ToString();
            return await SessionAuth.GetActiveUserByToken(_context, token);
        }

        [HttpGet("me")]
        public async Task<IActionResult> GetMyTeams()
        {
            var me = await GetMe();
            if (me == null) return Unauthorized("Invalid or expired token.");

            var teams = await _context.TeamMembers
                .Where(tm => tm.UserId == me.Id)
                .Include(tm => tm.Team)
                .OrderByDescending(tm => tm.JoinDate)
                .Select(tm => new
                {
                    tm.Team.Id,
                    tm.Team.Name,
                    tm.Team.Description,
                    tm.Team.InviteCode,
                    tm.Team.OwnerId,
                    myRole = tm.Role,
                    tm.Team.CreatedAt
                })
                .ToListAsync();

            return Ok(teams);
        }

        [HttpGet("{teamId:int}")]
        public async Task<IActionResult> GetTeam(int teamId)
        {
            var me = await GetMe();
            if (me == null) return Unauthorized("Invalid or expired token.");

            var isMember = await _context.TeamMembers.AnyAsync(tm => tm.TeamId == teamId && tm.UserId == me.Id);
            if (!isMember) return Forbid();

            var team = await _context.Teams.FirstOrDefaultAsync(t => t.Id == teamId);
            if (team == null) return NotFound("Team not found");

            return Ok(new
            {
                team.Id,
                team.Name,
                team.Description,
                team.InviteCode,
                team.OwnerId,
                team.CreatedAt
            });
        }

        [HttpGet("{teamId:int}/members")]
        public async Task<IActionResult> GetMembers(int teamId)
        {
            var me = await GetMe();
            if (me == null) return Unauthorized("Invalid or expired token.");

            var isMember = await _context.TeamMembers.AnyAsync(tm => tm.TeamId == teamId && tm.UserId == me.Id);
            if (!isMember) return Forbid();

            var members = await _context.TeamMembers
                .Where(tm => tm.TeamId == teamId)
                .Include(tm => tm.User)
                .OrderByDescending(tm => tm.JoinDate)
                .Select(tm => new
                {
                    tm.UserId,
                    tm.User.Email,
                    tm.User.AvatarUrl,
                    tm.Role,
                    tm.JoinDate
                })
                .ToListAsync();

            return Ok(members);
        }

        [HttpPost]
        public async Task<IActionResult> Create(CreateTeamDto dto)
        {
            var me = await GetMe();
            if (me == null) return Unauthorized("Invalid or expired token.");

            if (string.IsNullOrWhiteSpace(dto.Name))
                return BadRequest("Name is required.");

            string inviteCode;
            do
            {
                inviteCode = GenerateInviteCode();
            } while (await _context.Teams.AnyAsync(t => t.InviteCode == inviteCode));

            var team = new Team
            {
                OwnerId = me.Id,
                Name = dto.Name.Trim(),
                Description = dto.Description,
                InviteCode = inviteCode,
                CreatedAt = DateTime.Now
            };

            _context.Teams.Add(team);
            await _context.SaveChangesAsync();

            // Owner becomes a team member too
            var ownerMember = new TeamMember
            {
                TeamId = team.Id,
                UserId = me.Id,
                // DB has a CHECK constraint on team_members.role; "owner" is not allowed.
                // We treat Team.OwnerId as the source of truth for ownership.
                Role = "member",
                JoinDate = DateTime.Now
            };
            _context.TeamMembers.Add(ownerMember);

            // If user is just 'user', upgrade them to 'team_owner'
            if (me.Role == "user")
            {
                me.Role = "team_owner";
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                team.Id,
                team.Name,
                team.Description,
                team.InviteCode,
                team.OwnerId,
                team.CreatedAt
            });
        }

        [HttpPost("join")]
        public async Task<IActionResult> Join(JoinTeamDto dto)
        {
            var me = await GetMe();
            if (me == null) return Unauthorized("Invalid or expired token.");

            if (string.IsNullOrWhiteSpace(dto.InviteCode))
                return BadRequest("InviteCode is required.");

            var code = dto.InviteCode.Trim();
            var team = await _context.Teams.FirstOrDefaultAsync(t => t.InviteCode == code);
            if (team == null) return NotFound("Invalid invite code.");

            var already = await _context.TeamMembers.AnyAsync(tm => tm.TeamId == team.Id && tm.UserId == me.Id);
            if (already) return Ok("Already joined");

            var member = new TeamMember
            {
                TeamId = team.Id,
                UserId = me.Id,
                Role = "member",
                JoinDate = DateTime.Now
            };

            _context.TeamMembers.Add(member);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                team.Id,
                team.Name,
                team.Description,
                team.InviteCode,
                team.OwnerId
            });
        }

        [HttpPost("{teamId:int}/leave")]
        public async Task<IActionResult> Leave(int teamId)
        {
            var me = await GetMe();
            if (me == null) return Unauthorized("Invalid or expired token.");

            var team = await _context.Teams.FindAsync(teamId);
            if (team == null) return NotFound("Team not found");

            if (team.OwnerId == me.Id)
                return BadRequest("Owner cannot leave the team. Transfer ownership or delete team.");

            var member = await _context.TeamMembers
                .FirstOrDefaultAsync(tm => tm.TeamId == teamId && tm.UserId == me.Id);

            if (member == null) return Ok("Not a member");

            _context.TeamMembers.Remove(member);
            await _context.SaveChangesAsync();

            return Ok("Left team");
        }
    }
}

