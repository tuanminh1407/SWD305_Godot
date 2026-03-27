using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.DTO;
using SWD305.Models;
using SWD305.Security;

namespace SWD305.Controllers
{
    [ApiController]
    [Route("api/tasks")]
    public class TaskController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public TaskController(VnegSystemContext context)
        {
            _context = context;
        }

        private async Task<User?> GetMe()
        {
            var token = Request.Headers["X-Session-Token"].ToString();
            return await SessionAuth.GetActiveUserByToken(_context, token);
        }

        [HttpGet("team/{teamId:int}")]
        public async Task<IActionResult> GetTeamTasks(int teamId)
        {
            var me = await GetMe();
            if (me == null) return Unauthorized("Invalid or expired token.");

            var isMember = await _context.TeamMembers.AnyAsync(tm => tm.TeamId == teamId && tm.UserId == me.Id);
            if (!isMember) return Forbid("Not a member of this team");

            var tasks = await _context.Tasks
                .Where(t => t.TeamId == teamId && t.IsActive == true)
                .OrderByDescending(t => t.CreatedAt)
                .Select(t => new
                {
                    t.Id,
                    t.TeamId,
                    t.Type,
                    t.Criteria, // This holds the GameId for tests
                    t.Reward,
                    t.DueDate,
                    t.CreatedAt,
                    t.CreatedBy,
                    CreatedByName = t.CreatedByNavigation.Email
                })
                .ToListAsync();

            // Append user's progress
            var taskIds = tasks.Select(t => t.Id).ToList();
            var progresses = await _context.TaskProgresses
                .Where(p => p.UserId == me.Id && taskIds.Contains(p.TaskId))
                .ToDictionaryAsync(p => p.TaskId, p => p);

            var result = tasks.Select(t => new
            {
                t.Id,
                t.TeamId,
                t.Type,
                GameId = int.Parse(t.Criteria ?? "0"),
                t.Reward,
                t.DueDate,
                t.CreatedAt,
                t.CreatedBy,
                t.CreatedByName,
                Status = progresses.ContainsKey(t.Id) ? progresses[t.Id].Status : "not_started",
                Progress = progresses.ContainsKey(t.Id) ? progresses[t.Id].CurrentProgress : 0
            });

            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> CreateTask(CreateTaskDto dto)
        {
            var me = await GetMe();
            if (me == null) return Unauthorized("Invalid or expired token.");

            var team = await _context.Teams.FindAsync(dto.TeamId);
            if (team == null) return NotFound("Team not found");
            if (team.OwnerId != me.Id) return Forbid("Only team owner can create tasks");

            var task = new SWD305.Models.Task
            {
                TeamId = dto.TeamId,
                Type = "team_test",
                Criteria = dto.GameId.ToString(), // Storing game ID here
                Reward = dto.Reward ?? "100_coins",
                CreatedBy = me.Id,
                DueDate = dto.DueDate,
                IsActive = true,
                CreatedAt = DateTime.Now,
                UpdatedAt = DateTime.Now
            };

            _context.Tasks.Add(task);
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException ex)
            {
                return BadRequest(new
                {
                    message = "Lỗi lưu Database khi tạo Task.",
                    detail = ex.InnerException?.Message ?? ex.Message
                });
            }

            return Ok(new
            {
                task.Id,
                task.TeamId,
                task.Criteria,
                task.Reward,
                task.CreatedAt
            });
        }

        [HttpPost("{taskId:int}/start")]
        public async Task<IActionResult> StartTask(int taskId)
        {
            var me = await GetMe();
            if (me == null) return Unauthorized("Invalid or expired token.");

            var task = await _context.Tasks.FindAsync(taskId);
            if (task == null || task.IsActive != true) return NotFound("Task not found or inactive");

            var progress = await _context.TaskProgresses
                .FirstOrDefaultAsync(p => p.TaskId == taskId && p.UserId == me.Id);

            if (progress == null)
            {
                progress = new TaskProgress
                {
                    TaskId = taskId,
                    UserId = me.Id,
                    CurrentProgress = 0,
                    TargetValue = 100, // Assuming 100% is complete
                    Status = "in_progress"
                };
                _context.TaskProgresses.Add(progress);
                await _context.SaveChangesAsync();
            }
            else if (progress.Status == "completed")
            {
                return BadRequest("Task already completed");
            }

            int gameId = int.Parse(task.Criteria ?? "1");

            var session = new GameSession
            {
                UserId = me.Id,
                GameId = gameId,
                Score = 0,
                Stars = 0,
                Coins = 0
            };

            _context.GameSessions.Add(session);
            await _context.SaveChangesAsync();

            return Ok(new { sessionId = session.Id, taskId = task.Id, gameId = gameId });
        }

        [HttpPost("{taskId:int}/complete")]
        public async Task<IActionResult> CompleteTask(int taskId, [FromBody] CompleteTaskDto dto)
        {
            var me = await GetMe();
            if (me == null) return Unauthorized("Invalid or expired token.");

             var progress = await _context.TaskProgresses
                .FirstOrDefaultAsync(p => p.TaskId == taskId && p.UserId == me.Id);

            if (progress == null) return BadRequest("Task not started");
            if (progress.Status == "completed") return Ok(new { message = "Already completed", reward = progress.Task.Reward });

            var session = await _context.GameSessions.FindAsync(dto.SessionId);
            if (session == null || session.UserId != me.Id) return NotFound("Invalid session");

            // Mark as complete regardless of score for now
            progress.Status = "completed";
            progress.CurrentProgress = 100;
            progress.CompletedAt = DateTime.Now;

            // TODO: In a real system you would parse the reward and actually award the user's Gold/Stars here

            await _context.SaveChangesAsync();

            return Ok(new { message = "Task completed!", reward = progress.Task.Reward });
        }
    }
}
