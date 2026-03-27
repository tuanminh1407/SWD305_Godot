using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.DTO;
using SWD305.Models;
using SWD305.Security;

using Microsoft.AspNetCore.Authorization;

namespace SWD305.Controllers
{
    [Authorize(Roles = "team_owner")]
    [ApiController]
    [Route("api/team-owner")]
    public class TeamOwnerController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public TeamOwnerController(VnegSystemContext context)
        {
            _context = context;
        }

        private async Task<User?> GetMe()
        {
            var token = Request.Headers["X-Session-Token"].ToString();
            return await SessionAuth.GetActiveUserByToken(_context, token);
        }

        [HttpPut("{teamId:int}")]
        public async Task<IActionResult> UpdateTeam(int teamId, UpdateTeamDto dto)
        {

            var me = await GetMe();
            var team = await _context.Teams.FindAsync(teamId);

            if (team == null) return NotFound("Team not found");
            if (team.OwnerId != me!.Id) return Forbid("You are not the owner of this team.");

            if (!string.IsNullOrWhiteSpace(dto.Name))
            {
                team.Name = dto.Name.Trim();
            }
            if (dto.Description != null)
            {
                team.Description = dto.Description;
            }

            await _context.SaveChangesAsync();
            return Ok(new { team.Id, team.Name, team.Description });
        }

        [HttpPost("{teamId:int}/remove-member")]
        public async Task<IActionResult> RemoveMember(int teamId, RemoveMemberDto dto)
        {

            var me = await GetMe();
            var team = await _context.Teams.FindAsync(teamId);

            if (team == null) return NotFound("Team not found");
            if (team.OwnerId != me!.Id) return Forbid("You are not the owner of this team.");

            if (dto.UserId == me.Id) return BadRequest("You cannot remove yourself.");

            var member = await _context.TeamMembers
                .FirstOrDefaultAsync(tm => tm.TeamId == teamId && tm.UserId == dto.UserId);

            if (member == null) return NotFound("User is not a member of this team.");

            _context.TeamMembers.Remove(member);
            await _context.SaveChangesAsync();

            return Ok("Member removed successfully.");
        }

        [HttpDelete("{teamId:int}")]
        public async Task<IActionResult> DeleteTeam(int teamId)
        {

            var me = await GetMe();
            var team = await _context.Teams.FindAsync(teamId);

            if (team == null) return NotFound("Team not found");
            if (team.OwnerId != me!.Id) return Forbid("You are not the owner of this team.");

            var members = await _context.TeamMembers.Where(tm => tm.TeamId == teamId).ToListAsync();
            _context.TeamMembers.RemoveRange(members);

            _context.Teams.Remove(team);
            await _context.SaveChangesAsync();

            return Ok("Team deleted successfully.");
        }
        [HttpPost("{teamId:int}/add-member")]
        public async Task<IActionResult> AddMember(int teamId, [FromBody] AddMemberDto dto)
        {
            var me = await GetMe();
            var team = await _context.Teams.FindAsync(teamId);

            if (team == null) return NotFound("Team not found");
            if (team.OwnerId != me!.Id) return Forbid("You are not the owner of this team.");

            var already = await _context.TeamMembers
                .AnyAsync(tm => tm.TeamId == teamId && tm.UserId == dto.UserId);
            if (already) return BadRequest("User is already a member of this team.");

            var member = new TeamMember
            {
                TeamId = teamId,
                UserId = dto.UserId,
                Role = "member",
                JoinDate = DateTime.Now
            };

            _context.TeamMembers.Add(member);
            await _context.SaveChangesAsync();

            return Ok("Member added successfully.");
        }
    }
}
