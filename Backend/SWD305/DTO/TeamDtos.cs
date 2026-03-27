namespace SWD305.DTO
{
    public class CreateTeamDto
    {
        public string Name { get; set; } = null!;
        public string? Description { get; set; }
    }

    public class JoinTeamDto
    {
        public string InviteCode { get; set; } = null!;
    }

    public class UpdateTeamDto
    {
        public string? Name { get; set; }
        public string? Description { get; set; }
    }

    public class RemoveMemberDto
    {
        public int UserId { get; set; }
    }

    public class AddMemberDto
    {
        public int UserId { get; set; }
    }
}

