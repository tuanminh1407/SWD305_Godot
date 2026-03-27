using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.DTO;
using SWD305.Models;

using Microsoft.AspNetCore.Authorization;

namespace SWD305.Controllers
{
    [Authorize(Roles = "admin")]
    [ApiController]
    [Route("api/admin/games")]
    public class AdminGameController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public AdminGameController(VnegSystemContext context)
        {
            _context = context;
        }

        // GET ALL
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var games = await _context.Games
                .Include(g => g.Map)
                .Select(g => new
                {
                    g.Id,
                    g.MapId,
                    g.Name,
                    g.GameType,
                    g.Flow,
                    g.OrderIndex,
                    g.IsPremium,
                    Map = new
                    {
                        g.Map.Id,
                        g.Map.Name,
                        g.Map.GradeId,
                        g.Map.OrderIndex,
                        g.Map.IsActive
                    }
                })
                .ToListAsync();

            return Ok(games);
        }

        // GET BY ID
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var game = await _context.Games
                .Include(g => g.Map)
                .Where(g => g.Id == id)
                .Select(g => new
                {
                    g.Id,
                    g.MapId,
                    g.Name,
                    g.GameType,
                    g.Flow,
                    g.OrderIndex,
                    g.IsPremium,
                    Map = new
                    {
                        g.Map.Id,
                        g.Map.Name,
                        g.Map.GradeId,
                        g.Map.OrderIndex,
                        g.Map.IsActive
                    }
                })
                .FirstOrDefaultAsync();

            if (game == null)
                return NotFound();

            return Ok(game);
        }

        // CREATE
        [HttpPost]
        public async Task<IActionResult> Create(CreateGameDto dto)
        {
            var mapExists = await _context.Maps.AnyAsync(m => m.Id == dto.MapId);
            if (!mapExists)
                return BadRequest("MapId does not exist");

            var game = new Game
            {
                MapId = dto.MapId,
                Name = dto.Name,
                GameType = dto.GameType,
                Flow = dto.Flow,
                OrderIndex = dto.OrderIndex,
                IsPremium = dto.IsPremium
            };

            _context.Games.Add(game);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                game.Id,
                game.MapId,
                game.Name,
                game.GameType,
                game.Flow,
                game.OrderIndex,
                game.IsPremium
            });
        }

        // UPDATE
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, UpdateGameDto dto)
        {
            var game = await _context.Games.FindAsync(id);
            if (game == null)
                return NotFound();

            game.MapId = dto.MapId;
            game.Name = dto.Name;
            game.GameType = dto.GameType;
            game.Flow = dto.Flow;
            game.OrderIndex = dto.OrderIndex;
            game.IsPremium = dto.IsPremium;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                game.Id,
                game.MapId,
                game.Name,
                game.GameType,
                game.Flow,
                game.OrderIndex,
                game.IsPremium
            });
        }

        // SOFT DELETE
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var game = await _context.Games.FindAsync(id);
            if (game == null)
                return NotFound();

            game.IsActive = false;
            await _context.SaveChangesAsync();

            return Ok("Soft-deleted successfully");
        }
    }

}
