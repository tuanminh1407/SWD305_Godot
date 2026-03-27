using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.DTO;
using SWD305.Models;

namespace SWD305.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class GameController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public GameController(VnegSystemContext context)
        {
            _context = context;
        }

        // =============================
        // START GAME
        // =============================
        [HttpPost("start")]
        public async Task<IActionResult> StartGame(StartGameRequest request)
        {
            var session = new GameSession
            {
                UserId = request.UserId,
                GameId = request.GameId,
                Score = 0,
                Stars = 0,
                Coins = 0
            };

            _context.GameSessions.Add(session);
            await _context.SaveChangesAsync();

            return Ok(new { sessionId = session.Id });
        }


        // =============================
        // GET QUESTIONS
        // =============================
        [HttpGet("{sessionId}/questions")]
        public async Task<IActionResult> GetQuestions(int sessionId)
        {
            var session = await _context.GameSessions.FindAsync(sessionId);
            if (session == null) return NotFound("Session not found");

            var questions = await _context.Questions
                .Where(q => q.GameId == session.GameId && q.IsActive == true)
                .Select(q => new
                {
                    q.Id,
                    q.Data,
                    q.Answer,
                    q.ImageUrl,
                    q.AudioUrl,
                    q.QuestionType,
                    q.Difficulty
                })
                .ToListAsync();

            return Ok(questions);
        }

        // =============================
        // SUBMIT GAME (SERVER CHECK)
        // =============================
        [HttpPost("{sessionId}/submit")]
        public async Task<IActionResult> Submit(int sessionId, SubmitGameDto request)
        {
            var session = await _context.GameSessions
                .FirstOrDefaultAsync(s => s.Id == sessionId);

            if (session == null) return NotFound("Session not found");

            int correctCount = 0;
            var answeredQuestionIds = request.Answers.Select(a => a.QuestionId).Distinct().ToList();
            if (answeredQuestionIds.Count == 0)
            {
                session.Score = 0;
                session.Accuracy = 0;
                session.Stars = 1;
                session.Coins = 5;
                session.CompletedAt = DateTime.Now;
                await _context.SaveChangesAsync();

                return Ok(new { session.Score, session.Accuracy, session.Stars, session.Coins });
            }

            var questions = await _context.Questions
                .Where(q => answeredQuestionIds.Contains(q.Id))
                .Select(q => new { q.Id, q.Data, q.Answer })
                .ToListAsync();

            var questionInfoById = questions.ToDictionary(q => q.Id, q => q);
            var correctQuestionIds = new HashSet<int>();
            var wrongQuestionIds = new HashSet<int>();

            foreach (var item in request.Answers)
            {
                if (!questionInfoById.TryGetValue(item.QuestionId, out var qInfo)) continue;

                bool isCorrectChoice = false;

                // qInfo.Answer might be a straightforward exact string like "1", text like "apple", or a JSON array like "[1]" or "[\"apple\"]"
                string userAnsStr = item.SelectedAnswer ?? item.SelectedAnswerId?.ToString() ?? "";

                if (string.Equals(qInfo.Answer, userAnsStr, StringComparison.OrdinalIgnoreCase))
                {
                    isCorrectChoice = true;
                }
                else
                {
                    try
                    {
                        using var doc = JsonDocument.Parse(qInfo.Answer);
                        if (doc.RootElement.ValueKind == JsonValueKind.Array)
                        {
                            foreach (var element in doc.RootElement.EnumerateArray())
                            {
                                if (element.ToString().Equals(userAnsStr, StringComparison.OrdinalIgnoreCase))
                                {
                                    isCorrectChoice = true;
                                    break;
                                }
                            }
                            
                            // Backwards compatibility for exact int match if the new string mapping is falsy
                            if (!isCorrectChoice && item.SelectedAnswerId.HasValue)
                            {
                                foreach (var element in doc.RootElement.EnumerateArray())
                                {
                                    if (element.ValueKind == JsonValueKind.Number && element.GetInt32() == item.SelectedAnswerId.Value)
                                    {
                                        isCorrectChoice = true;
                                        break;
                                    }
                                }
                            }
                        }
                    }
                    catch
                    {
                        // Ignore parse errors, treat as wrong
                    }
                }

                if (isCorrectChoice)
                {
                    correctCount++;
                    correctQuestionIds.Add(item.QuestionId);
                }
                else
                {
                    wrongQuestionIds.Add(item.QuestionId);
                }
            }

            int total = request.Answers.Count;

            session.Score = correctCount * 10;
            session.Accuracy = total == 0 ? 0 : (correctCount * 100m) / total;
            session.Stars = session.Accuracy >= 90 ? 3 :
                            session.Accuracy >= 70 ? 2 : 1;
            session.Coins = session.Stars * 5;
            session.CompletedAt = DateTime.Now;

            // =============================
            // GRAMMAR TRACKING (optional for demo)
            // - record wrong questions as GameError
            // - update UserGrammarProgress by QuestionGrammar mapping
            // =============================
            var now = DateTime.Now;

            if (wrongQuestionIds.Count > 0)
            {
                var errors = wrongQuestionIds
                    .Select(qid => new GameError
                    {
                        GameSessionId = session.Id,
                        QuestionId = qid,
                        ErrorType = "wrong_answer"
                    })
                    .ToList();

                _context.GameErrors.AddRange(errors);
                await _context.SaveChangesAsync();

                // Map question -> errorId
                var errorIdByQuestionId = errors.ToDictionary(e => e.QuestionId, e => e.Id);

                var wrongMappings = await _context.QuestionGrammars
                    .Where(qg => wrongQuestionIds.Contains(qg.QuestionId))
                    .Select(qg => new { qg.QuestionId, qg.GrammarTopicId })
                    .ToListAsync();

                var errorGrammars = wrongMappings
                    .Where(m => errorIdByQuestionId.ContainsKey(m.QuestionId))
                    .Select(m => new GameErrorGrammar
                    {
                        GameErrorId = errorIdByQuestionId[m.QuestionId],
                        GrammarTopicId = m.GrammarTopicId
                    })
                    .ToList();

                if (errorGrammars.Count > 0)
                {
                    _context.GameErrorGrammars.AddRange(errorGrammars);
                    await _context.SaveChangesAsync();
                }
            }

            // Progress: upsert counts for grammar topics linked to answered questions
            var qgMappingsAll = await _context.QuestionGrammars
                .Where(qg => answeredQuestionIds.Contains(qg.QuestionId))
                .Select(qg => new { qg.QuestionId, qg.GrammarTopicId })
                .ToListAsync();

            if (qgMappingsAll.Count > 0)
            {
                var deltas = qgMappingsAll
                    .GroupBy(m => m.GrammarTopicId)
                    .Select(g => new
                    {
                        GrammarTopicId = g.Key,
                        CorrectDelta = g.Count(x => correctQuestionIds.Contains(x.QuestionId)),
                        WrongDelta = g.Count(x => wrongQuestionIds.Contains(x.QuestionId))
                    })
                    .Where(x => x.CorrectDelta > 0 || x.WrongDelta > 0)
                    .ToList();

                var topicIds = deltas.Select(d => d.GrammarTopicId).Distinct().ToList();
                var existing = await _context.UserGrammarProgresses
                    .Where(p => p.UserId == session.UserId && topicIds.Contains(p.GrammarTopicId))
                    .ToListAsync();

                foreach (var d in deltas)
                {
                    var p = existing.FirstOrDefault(x => x.GrammarTopicId == d.GrammarTopicId);
                    if (p == null)
                    {
                        p = new UserGrammarProgress
                        {
                            UserId = session.UserId,
                            GrammarTopicId = d.GrammarTopicId,
                            CorrectCount = 0,
                            WrongCount = 0,
                            MasteryLevel = 0,
                            LastPracticedAt = now
                        };
                        _context.UserGrammarProgresses.Add(p);
                        existing.Add(p);
                    }

                    p.CorrectCount = (p.CorrectCount ?? 0) + d.CorrectDelta;
                    p.WrongCount = (p.WrongCount ?? 0) + d.WrongDelta;
                    p.LastPracticedAt = now;

                    var totalAttempts = (p.CorrectCount ?? 0) + (p.WrongCount ?? 0);
                    p.MasteryLevel = totalAttempts == 0 ? 0 : ((p.CorrectCount ?? 0) * 100m) / totalAttempts;
                }

                await _context.SaveChangesAsync();
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                session.Score,
                session.Accuracy,
                session.Stars,
                session.Coins
            });
        }

        // =============================
        // GET GAMES BY MAP
        // =============================
        [HttpGet("by-map/{mapId}")]
        public async Task<IActionResult> GetGamesByMap(int mapId)
        {
            var games = await _context.Games
                .Where(g => g.MapId == mapId)
                .Select(g => new
                {
                    g.Id,
                    g.Name,
                    g.GameType,
                    g.OrderIndex,
                    g.IsPremium
                })
                .ToListAsync();

            return Ok(games);
        }
    }

    // =============================
    // DTO
    // =============================
    public class SubmitGameDto
    {
        public List<UserAnswerDto> Answers { get; set; } = new();
    }

    public class UserAnswerDto
    {
        public int QuestionId { get; set; }
        public int? SelectedAnswerId { get; set; }
        public string? SelectedAnswer { get; set; }
    }
}
