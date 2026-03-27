using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.DTO;
using SWD305.Models;

using Microsoft.AspNetCore.Authorization;

namespace SWD305.Controllers
{
    [Authorize(Roles = "admin")]
    [ApiController]
    [Route("api/admin/questions")]
    public class AdminQuestionController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public AdminQuestionController(VnegSystemContext context)
        {
            _context = context;
        }

        // GET ALL
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var questions = await _context.Questions
                .Include(q => q.Game)
                .ToListAsync();

            return Ok(questions);
        }

        // GET BY ID
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var question = await _context.Questions.FindAsync(id);
            if (question == null) return NotFound();

            return Ok(question);
        }

        // CREATE
        [HttpPost]
        public async Task<IActionResult> Create(CreateQuestionDto dto)
        {
            var gameExists = await _context.Games.AnyAsync(g => g.Id == dto.GameId);
            if (!gameExists)
            {
                return BadRequest("GameId does not exist.");
            }

            var question = new Question
            {
                GameId = dto.GameId,
                Data = dto.Data,
                Answer = dto.Answer,
                ImageUrl = dto.ImageUrl,
                AudioUrl = dto.AudioUrl,
                QuestionType = dto.QuestionType,
                Difficulty = dto.Difficulty,
                Explanation = dto.Explanation,
                IsActive = dto.IsActive ?? true
            };

            _context.Questions.Add(question);
            await _context.SaveChangesAsync();

            return Ok(question);
        }

        // UPDATE
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, UpdateQuestionDto dto)
        {
            var question = await _context.Questions.FindAsync(id);
            if (question == null) return NotFound();

            var gameExists = await _context.Games.AnyAsync(g => g.Id == dto.GameId);
            if (!gameExists)
            {
                return BadRequest("GameId does not exist.");
            }

            question.GameId = dto.GameId;
            question.Data = dto.Data;
            question.Answer = dto.Answer;
            question.ImageUrl = dto.ImageUrl;
            question.AudioUrl = dto.AudioUrl;
            question.QuestionType = dto.QuestionType;
            question.Difficulty = dto.Difficulty;
            question.Explanation = dto.Explanation;
            question.IsActive = dto.IsActive ?? question.IsActive;

            await _context.SaveChangesAsync();

            return Ok(question);
        }

        // SOFT DELETE
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var question = await _context.Questions.FindAsync(id);
            if (question == null) return NotFound();

            question.IsActive = false;
            await _context.SaveChangesAsync();

            return Ok("Soft-deleted successfully");
        }
    }

}
