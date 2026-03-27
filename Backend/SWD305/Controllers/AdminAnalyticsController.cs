using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.Models;
using Microsoft.AspNetCore.Authorization;

namespace SWD305.Controllers
{
    [Authorize(Roles = "admin")]
    [ApiController]
    [Route("api/admin/analytics")]
    public class AdminAnalyticsController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public AdminAnalyticsController(VnegSystemContext context)
        {
            _context = context;
        }

        // ── USER STATS: DAU, MAU, Total, New (7d) ──
        [HttpGet("user-stats")]
        public async Task<IActionResult> GetUserStats()
        {
            var now = DateTime.Now;
            var today = now.Date;
            var thirtyDaysAgo = today.AddDays(-30);
            var sevenDaysAgo = today.AddDays(-7);

            var totalUsers = await _context.Users.CountAsync();
            var newUsersLast7d = await _context.Users
                .CountAsync(u => u.CreatedAt >= sevenDaysAgo);

            // DAU: distinct users who completed a game session today
            var dau = await _context.GameSessions
                .Where(gs => gs.CompletedAt != null && gs.CompletedAt.Value.Date == today)
                .Select(gs => gs.UserId)
                .Distinct()
                .CountAsync();

            // MAU: distinct users who completed a game session in last 30 days
            var mau = await _context.GameSessions
                .Where(gs => gs.CompletedAt != null && gs.CompletedAt >= thirtyDaysAgo)
                .Select(gs => gs.UserId)
                .Distinct()
                .CountAsync();

            return Ok(new
            {
                totalUsers,
                newUsersLast7d,
                dau,
                mau,
                date = today
            });
        }

        // ── RETENTION: D1, D7, D30 ──
        [HttpGet("retention")]
        public async Task<IActionResult> GetRetention()
        {
            var now = DateTime.Now;

            // Users who signed up in the last 30 days
            var recentUsers = await _context.Users
                .Where(u => u.CreatedAt >= now.AddDays(-30))
                .Select(u => new { u.Id, u.CreatedAt })
                .ToListAsync();

            if (recentUsers.Count == 0)
                return Ok(new { d1 = 0.0, d7 = 0.0, d30 = 0.0, cohortSize = 0 });

            var userIds = recentUsers.Select(u => u.Id).ToList();
            var sessions = await _context.GameSessions
                .Where(gs => userIds.Contains(gs.UserId) && gs.CompletedAt != null)
                .Select(gs => new { gs.UserId, gs.CompletedAt })
                .ToListAsync();

            int d1Count = 0, d7Count = 0, d30Count = 0;
            foreach (var user in recentUsers)
            {
                var userSessions = sessions
                    .Where(s => s.UserId == user.Id)
                    .Select(s => (s.CompletedAt!.Value - user.CreatedAt!.Value).Days)
                    .ToHashSet();

                if (userSessions.Any(d => d >= 1)) d1Count++;
                if (userSessions.Any(d => d >= 7)) d7Count++;
                if (userSessions.Any(d => d >= 30)) d30Count++;
            }

            var total = (double)recentUsers.Count;
            return Ok(new
            {
                d1 = Math.Round(d1Count / total * 100, 1),
                d7 = Math.Round(d7Count / total * 100, 1),
                d30 = Math.Round(d30Count / total * 100, 1),
                cohortSize = recentUsers.Count
            });
        }

        // ── DEMOGRAPHICS: Users by Grade & Region ──
        [HttpGet("demographics")]
        public async Task<IActionResult> GetDemographics()
        {
            var byGrade = await _context.Users
                .GroupBy(u => u.Grade)
                .Select(g => new { grade = g.Key ?? 0, count = g.Count() })
                .OrderBy(g => g.grade)
                .ToListAsync();

            var byRegion = await _context.Users
                .GroupBy(u => u.Region ?? "Unknown")
                .Select(g => new { region = g.Key, count = g.Count() })
                .ToListAsync();

            return Ok(new { byGrade, byRegion });
        }

        // ── SYSTEM HEALTH: Uptime, Concurrent Users, Error Count ──
        [HttpGet("system-health")]
        public async Task<IActionResult> GetSystemHealth()
        {
            var now = DateTime.Now;

            // Concurrent users: active sessions not expired
            var concurrentUsers = await _context.Sessions
                .CountAsync(s => s.ExpiresAt > now);

            // Error count from SystemLog (last 24h)
            var errorCount = await _context.SystemLogs
                .CountAsync(l => l.CreatedAt >= now.AddDays(-1)
                    && l.Action != null
                    && l.Action.Contains("error"));

            // Total requests (all SystemLog entries in last 24h)
            var totalLogs24h = await _context.SystemLogs
                .CountAsync(l => l.CreatedAt >= now.AddDays(-1));

            // Uptime approximation: (total - errors) / total * 100
            var uptime = totalLogs24h > 0
                ? Math.Round((double)(totalLogs24h - errorCount) / totalLogs24h * 100, 2)
                : 100.0;

            return Ok(new
            {
                uptime,
                concurrentUsers,
                errorCount,
                totalLogs24h,
                alertUptimeLow = uptime < 99.5
            });
        }

        // ── CONTENT REPORTS: Most Played Games ──
        [HttpGet("content-reports")]
        public async Task<IActionResult> GetContentReports()
        {
            // Top 10 most played games
            var topGames = await _context.GameSessions
                .GroupBy(gs => gs.GameId)
                .Select(g => new
                {
                    gameId = g.Key,
                    sessionCount = g.Count(),
                    avgAccuracy = g.Average(gs => (double?)gs.Accuracy) ?? 0,
                    avgScore = g.Average(gs => (double?)gs.Score) ?? 0
                })
                .OrderByDescending(g => g.sessionCount)
                .Take(10)
                .ToListAsync();

            // Enrich with game names
            var gameIds = topGames.Select(g => g.gameId).ToList();
            var gameNames = await _context.Games
                .Where(g => gameIds.Contains(g.Id))
                .ToDictionaryAsync(g => g.Id, g => g.Name);

            var result = topGames.Select(g => new
            {
                g.gameId,
                gameName = gameNames.GetValueOrDefault(g.gameId, "Unknown"),
                g.sessionCount,
                g.avgAccuracy,
                g.avgScore
            });

            return Ok(result);
        }

        // ── ERROR HOTSPOTS: Grammar Fail Rates ──
        [HttpGet("error-hotspots")]
        public async Task<IActionResult> GetErrorHotspots()
        {
            var hotspots = await _context.GameErrorGrammars
                .GroupBy(eg => eg.GrammarTopicId)
                .Select(g => new
                {
                    grammarTopicId = g.Key,
                    errorCount = g.Count()
                })
                .OrderByDescending(g => g.errorCount)
                .Take(20)
                .ToListAsync();

            var topicIds = hotspots.Select(h => h.grammarTopicId).ToList();
            var topics = await _context.GrammarTopics
                .Where(t => topicIds.Contains(t.Id))
                .ToDictionaryAsync(t => t.Id, t => new { t.Name, t.Code });

            var result = hotspots.Select(h => new
            {
                h.grammarTopicId,
                topicName = topics.ContainsKey(h.grammarTopicId) ? topics[h.grammarTopicId].Name : "Unknown",
                topicCode = topics.ContainsKey(h.grammarTopicId) ? topics[h.grammarTopicId].Code : "",
                h.errorCount
            });

            return Ok(result);
        }

        // ── SYSTEM AUDIT LOGS ──
        [HttpGet("audit-logs")]
        public async Task<IActionResult> GetAuditLogs(
            [FromQuery] string? action,
            [FromQuery] int page = 1,
            [FromQuery] int size = 20)
        {
            var query = _context.SystemLogs
                .Include(l => l.User)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(action))
                query = query.Where(l => l.Action == action);

            var totalCount = await query.CountAsync();

            var logs = await query
                .OrderByDescending(l => l.CreatedAt)
                .Skip((page - 1) * size)
                .Take(size)
                .Select(l => new
                {
                    l.Id,
                    userId = l.UserId,
                    userEmail = l.User != null ? l.User.Email : "System",
                    l.Action,
                    l.Details,
                    l.CreatedAt
                })
                .ToListAsync();

            return Ok(new
            {
                logs,
                pagination = new
                {
                    page,
                    size,
                    totalCount,
                    totalPages = (int)Math.Ceiling(totalCount / (double)size)
                }
            });
        }

        // ── CSV EXPORT ──
        [HttpGet("export/{type}")]
        public async Task<IActionResult> ExportCsv(string type)
        {
            string csv = "";
            string filename = $"{type}_{DateTime.Now:yyyyMMdd}.csv";

            switch (type.ToLower())
            {
                case "users":
                    var users = await _context.Users.ToListAsync();
                    csv = "Id,Email,Phone,Grade,Region,Role,IsActive,CreatedAt\n";
                    csv += string.Join("\n", users.Select(u =>
                        $"{u.Id},{u.Email},{u.Phone},{u.Grade},{u.Region},{u.Role},{u.IsActive},{u.CreatedAt}"));
                    break;

                case "games":
                    var games = await _context.Games.ToListAsync();
                    csv = "Id,Name,MapId,GameType,OrderIndex,IsPremium,IsActive\n";
                    csv += string.Join("\n", games.Select(g =>
                        $"{g.Id},{g.Name},{g.MapId},{g.GameType},{g.OrderIndex},{g.IsPremium},{g.IsActive}"));
                    break;

                case "questions":
                    var questions = await _context.Questions.ToListAsync();
                    csv = "Id,GameId,QuestionType,Difficulty,IsActive,Answer\n";
                    csv += string.Join("\n", questions.Select(q =>
                        $"{q.Id},{q.GameId},{q.QuestionType},{q.Difficulty},{q.IsActive},{q.Answer}"));
                    break;

                default:
                    return BadRequest("Invalid export type. Use: users, games, questions");
            }

            var bytes = System.Text.Encoding.UTF8.GetBytes(csv);
            return File(bytes, "text/csv", filename);
        }
    }
}
