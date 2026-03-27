using System;
using System.Collections.Generic;

namespace SWD305.Models;

public partial class Game
{
    public int Id { get; set; }

    public int MapId { get; set; }

    public string Name { get; set; } = null!;

    public string? GameType { get; set; }

    public string? Flow { get; set; }

    public int? OrderIndex { get; set; }

    public bool? IsPremium { get; set; }

    public bool? IsActive { get; set; }

    public virtual ICollection<GameSession> GameSessions { get; set; } = new List<GameSession>();

    public virtual Map Map { get; set; } = null!;

    public virtual ICollection<Question> Questions { get; set; } = new List<Question>();
}
