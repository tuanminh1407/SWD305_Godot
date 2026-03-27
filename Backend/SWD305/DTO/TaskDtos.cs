namespace SWD305.DTO
{
    public class CreateTaskDto
    {
        public int TeamId { get; set; }
        public int GameId { get; set; }
        public string? Reward { get; set; }
        public DateTime? DueDate { get; set; }
    }


    public class CompleteTaskDto
    {
        public int SessionId { get; set; }
    }
}
