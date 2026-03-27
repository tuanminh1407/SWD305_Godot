using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.Models;

using Microsoft.AspNetCore.Authorization;

namespace SWD305.Controllers
{
    [Authorize(Roles = "admin")]
    [ApiController]
    [Route("api/admin/grammar-topics")]
    public class AdminGrammarTopicController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public AdminGrammarTopicController(VnegSystemContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var topics = await _context.GrammarTopics
                .Include(t => t.Parent)
                .OrderBy(t => t.Id)
                .ToListAsync();

            return Ok(topics);
        }

        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetById(int id)
        {
            var topic = await _context.GrammarTopics
                .Include(t => t.Parent)
                .FirstOrDefaultAsync(t => t.Id == id);

            if (topic == null) return NotFound("Grammar topic not found");
            return Ok(topic);
        }

        [HttpPost]
        public async Task<IActionResult> Create(GrammarTopic input)
        {
            if (input.ParentId.HasValue)
            {
                var parentExists = await _context.GrammarTopics.AnyAsync(t => t.Id == input.ParentId.Value);
                if (!parentExists) return BadRequest("ParentId does not exist.");
            }

            if (!string.IsNullOrWhiteSpace(input.Code))
            {
                var codeExists = await _context.GrammarTopics.AnyAsync(t => t.Code == input.Code);
                if (codeExists) return BadRequest("Code already exists.");
            }

            _context.GrammarTopics.Add(input);
            await _context.SaveChangesAsync();

            return Ok(input);
        }

        [HttpPut("{id:int}")]
        public async Task<IActionResult> Update(int id, GrammarTopic input)
        {
            var topic = await _context.GrammarTopics.FindAsync(id);
            if (topic == null) return NotFound("Grammar topic not found");

            if (input.ParentId.HasValue && input.ParentId.Value == id)
            {
                return BadRequest("ParentId cannot be the same as Id.");
            }

            if (input.ParentId.HasValue)
            {
                var parentExists = await _context.GrammarTopics.AnyAsync(t => t.Id == input.ParentId.Value);
                if (!parentExists) return BadRequest("ParentId does not exist.");
            }

            if (!string.IsNullOrWhiteSpace(input.Code) && input.Code != topic.Code)
            {
                var codeExists = await _context.GrammarTopics.AnyAsync(t => t.Code == input.Code);
                if (codeExists) return BadRequest("Code already exists.");
            }

            topic.ParentId = input.ParentId;
            topic.Code = input.Code;
            topic.Name = input.Name;
            topic.Description = input.Description;
            topic.Example = input.Example;
            topic.GradeMin = input.GradeMin;
            topic.GradeMax = input.GradeMax;
            topic.Difficulty = input.Difficulty;
            topic.IsActive = input.IsActive;

            await _context.SaveChangesAsync();
            return Ok(topic);
        }

        // SOFT DELETE
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var topic = await _context.GrammarTopics.FindAsync(id);
            if (topic == null) return NotFound("Grammar topic not found");

            topic.IsActive = false;
            await _context.SaveChangesAsync();

            return Ok("Soft-deleted successfully");
        }
    }
}

