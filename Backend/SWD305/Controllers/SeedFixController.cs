using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SWD305.Models;
using SystemTask = System.Threading.Tasks.Task;

namespace SWD305.Controllers
{
    [Route("api/admin/seed-fix")]
    [ApiController]
    public class SeedFixController : ControllerBase
    {
        private readonly VnegSystemContext _context;

        public SeedFixController(VnegSystemContext context)
        {
            _context = context;
        }

        private static string GetWikiUrl(string filename)
        {
            // Use Special:FilePath which handles redirects and filename encoding more robustly
            // URL structure: https://commons.wikimedia.org/w/index.php?title=Special:FilePath&file=FILENAME
            return $"https://commons.wikimedia.org/w/index.php?title=Special:FilePath&file={Uri.EscapeDataString(filename.Replace(" ", "_"))}";
        }

        [HttpPost]
        public async Task<IActionResult> Seed()
        {
            // 1. Clear existing data in correct order
            await _context.Database.ExecuteSqlRawAsync("DELETE FROM dbo.game_error_grammar;");
            await _context.Database.ExecuteSqlRawAsync("DELETE FROM dbo.game_errors;");
            await _context.Database.ExecuteSqlRawAsync("DELETE FROM dbo.game_sessions;");
            await _context.Database.ExecuteSqlRawAsync("DELETE FROM dbo.question_grammar;");
            await _context.Database.ExecuteSqlRawAsync("DELETE FROM dbo.questions;");
            await _context.Database.ExecuteSqlRawAsync("DELETE FROM dbo.games;");
            await _context.Database.ExecuteSqlRawAsync("DELETE FROM dbo.maps;");

            // Reset Identities
            await _context.Database.ExecuteSqlRawAsync("DBCC CHECKIDENT ('dbo.maps', RESEED, 0); DBCC CHECKIDENT ('dbo.games', RESEED, 0); DBCC CHECKIDENT ('dbo.questions', RESEED, 0);");

            // 2. Ensure Grades
            if (!await _context.Grades.AnyAsync(g => g.Id == 1)) _context.Grades.Add(new Grade { Id = 1, Name = "Lớp 1" });
            if (!await _context.Grades.AnyAsync(g => g.Id == 2)) _context.Grades.Add(new Grade { Id = 2, Name = "Lớp 2" });
            if (!await _context.Grades.AnyAsync(g => g.Id == 3)) _context.Grades.Add(new Grade { Id = 3, Name = "Lớp 3" });
            await _context.SaveChangesAsync();

            // 3. Create Maps
            var mapSoCap   = new Map { GradeId = 1, Name = "Sơ Cấp",   OrderIndex = 1, IsActive = true };
            var mapTrungCap = new Map { GradeId = 2, Name = "Trung Cấp", OrderIndex = 2, IsActive = true };
            var mapCaoCap  = new Map { GradeId = 3, Name = "Cao Cấp",   OrderIndex = 3, IsActive = true };
            _context.Maps.AddRange(mapSoCap, mapTrungCap, mapCaoCap);
            await _context.SaveChangesAsync();

            // 4. Seed each map
            await SeedMap(_context, mapSoCap,    1);
            await SeedMap(_context, mapTrungCap, 2);
            await SeedMap(_context, mapCaoCap,   3);

            var mapData  = await _context.Maps.Select(m => new { m.Id, m.Name }).ToListAsync();
            var gameData = await _context.Games.Select(g => new { g.Id, g.Name, g.MapId }).ToListAsync();

            return Ok(new
            {
                Message = "Seeding completed with real question bank!",
                Maps  = mapData,
                Games = gameData,
                TotalQuestions = await _context.Questions.CountAsync()
            });
        }

        // =====================================================================
        // SEED ONE MAP
        // =====================================================================
        private static async System.Threading.Tasks.Task SeedMap(VnegSystemContext ctx, Map map, int difficulty)
        {
            var gameTypes = new (string Name, string Type)[]
            {
                ("Ngữ Pháp",   "multiple_choice"),
                ("Chính Tả",   "fill_blank"),
                ("Nhìn Tranh", "picture_guess"),
                ("Vùng Miền",  "listen_choose"),
                ("Xếp Câu",    "drag_drop_sentence"),
                ("Ôn Tập",     "find_error"),
            };

            foreach (var (name, type) in gameTypes.Select((x, i) => (x, i)))
            {
                var game = new Game
                {
                    MapId      = map.Id,
                    Name       = name.Name,
                    GameType   = name.Type,
                    OrderIndex = type + 1,
                    IsPremium  = false
                };
                ctx.Games.Add(game);
                await ctx.SaveChangesAsync();

                var questions = BuildQuestions(game.Id, name.Type, difficulty);
                ctx.Questions.AddRange(questions);
                await ctx.SaveChangesAsync();
            }
        }

        // =====================================================================
        // QUESTION FACTORY — returns 6 questions per game type × difficulty
        // =====================================================================
        private static List<Question> BuildQuestions(int gameId, string gameType, int difficulty)
        {
            return gameType switch
            {
                "multiple_choice"    => MultipleChoice(gameId, difficulty),
                "fill_blank"         => FillBlank(gameId, difficulty),
                "picture_guess"      => PictureGuess(gameId, difficulty),
                "listen_choose"      => ListenChoose(gameId, difficulty),
                "drag_drop_sentence" => DragDropSentence(gameId, difficulty),
                "find_error"         => FindError(gameId, difficulty),
                _                    => MultipleChoice(gameId, difficulty),
            };
        }

        // =====================================================================
        // NGỮ PHÁP — multiple_choice (Sentence-based Grammar)
        // =====================================================================
        private static List<Question> MultipleChoice(int gameId, int diff)
        {
            var banks = new Dictionary<int, List<(string data, string answer, string explanation)>>
            {
                [1] = new()
                {
                    ("[\"Hôm nay em đi học ở trường.\", \"Hôm nay em học ở đi trường.\", \"Trường học ở em hôm nay đi.\"]", "Hôm nay em đi học ở trường.", "Chọn câu có trật tự từ đúng nhất:"),
                    ("[\"Con mèo đang nằm ngủ trên sân.\", \"Nằm ngủ đang con mèo trên sân.\", \"Trên sân con mèo nằm ngủ đang.\"]", "Con mèo đang nằm ngủ trên sân.", "Chọn câu miêu tả hành động đúng:"),
                    ("[\"Mẹ em đang nấu cơm ở trong bếp.\", \"Bếp trong ở cơm nấu đang mẹ em.\", \"Mẹ em nấu cơm đang bếp ở trong.\"]", "Mẹ em đang nấu cơm ở trong bếp.", "Chọn cấu trúc câu khẳng định đúng:"),
                    ("[\"Bầu trời hôm nay rất xanh và cao.\", \"Bầu trời xanh và cao rất hôm nay.\", \"Hôm nay rất xanh và cao bầu trời.\"]", "Bầu trời hôm nay rất xanh và cao.", "Chọn câu miêu tả thời tiết đúng:"),
                    ("[\"Em rất thích ăn quả táo đỏ này.\", \"Em quả táo đỏ này rất thích ăn.\", \"Thích ăn rất em quả táo đỏ này.\"]", "Em rất thích ăn quả táo đỏ này.", "Chọn câu thể hiện sở thích đúng:"),
                    ("[\"Bố em đi làm lúc bảy giờ sáng.\", \"Bảy giờ sáng lúc bố em đi làm.\", \"Làm đi bố em lúc bảy giờ sáng.\"]", "Bố em đi làm lúc bảy giờ sáng.", "Chọn câu chỉ thời gian hành động:"),
                },
                [2] = new()
                {
                    ("[\"Mặc dù trời mưa to nhưng tôi vẫn đi học.\", \"Trời mưa to mặc dù nhưng tôi vẫn đi học.\", \"Tôi vẫn đi học nhưng mặc dù trời mưa to.\"]", "Mặc dù trời mưa to nhưng tôi vẫn đi học.", "Chọn cặp quan hệ từ tương phản đúng:"),
                    ("[\"Cuốn sách mà bạn cho tôi mượn rất hay.\", \"Hay rất cuốn sách mà bạn cho tôi mượn.\", \"Bạn cho tôi mượn cuốn sách mà rất hay.\"]", "Cuốn sách mà bạn cho tôi mượn rất hay.", "Chọn câu có mệnh đề phụ quan hệ đúng:"),
                    ("[\"Nếu không chăm chỉ thì kết quả sẽ kém.\", \"Thì kết quả sẽ kém nếu không chăm chỉ.\", \"Chăm chỉ không nếu thì kết quả sẽ kém.\"]", "Nếu không chăm chỉ thì kết quả sẽ kém.", "Chọn cặp quan hệ từ giả thiết - kết quả:"),
                    ("[\"Cô ấy vừa xinh đẹp lại vừa thông minh.\", \"Cô ấy xinh đẹp lại thông minh vừa vừa.\", \"Vừa vừa xinh đẹp cô ấy lại thông minh.\"]", "Cô ấy vừa xinh đẹp lại vừa thông minh.", "Chọn cấu trúc liệt kê tính chất:"),
                    ("[\"Tôi đã hoàn thành bài tập về nhà rồi.\", \"Bài tập về nhà tôi đã hoàn thành rồi.\", \"Tôi hoàn thành bài tập về nhà đã rồi.\"]", "Tôi đã hoàn thành bài tập về nhà rồi.", "Chọn câu ở thì hoàn thành đúng nhất:"),
                    ("[\"Họ đang thảo luận về dự án mới này.\", \"Dự án mới này họ đang thảo luận về.\", \"Thảo luận về họ dự án mới này đang.\"]", "Họ đang thảo luận về dự án mới này.", "Chọn cấu trúc thảo luận vấn đề:"),
                },
                [3] = new()
                {
                    ("[\"Bức tranh này do chính tay họa sĩ vẽ.\", \"Vẽ bức tranh này họa sĩ do chính tay.\", \"Họa sĩ vẽ chính tay do bức tranh này.\"]", "Bức tranh này do chính tay họa sĩ vẽ.", "Chọn cấu trúc nhấn mạnh tác giả (bị động):"),
                    ("[\"Anh ấy làm việc một cách rất chuyên nghiệp.\", \"Cách một làm việc một anh ấy rất chuyên nghiệp.\", \"Chuyên nghiệp rất cách một anh ấy làm việc.\"]", "Anh ấy làm việc một cách rất chuyên nghiệp.", "Chọn cấu trúc trạng ngữ chỉ cách thức:"),
                    ("[\"Vì lợi ích chung, chúng ta cần đoàn kết.\", \"Chúng ta cần đoàn kết vì lợi ích chung.\", \"Lợi ích chung vì chúng ta cần đoàn kết.\"]", "Vì lợi ích chung, chúng ta cần đoàn kết.", "Chọn cấu trúc nêu mục đích đảo lên đầu:"),
                    ("[\"Quyển sách được viết bởi một tác giả nổi tiếng.\", \"Được viết bởi một tác giả nổi tiếp quyển sách.\", \"Một tác giả nổi tiếng bởi viết được quyển sách.\"]", "Quyển sách được viết bởi một tác giả nổi tiếng.", "Chọn cấu trúc câu bị động chuẩn mực:"),
                    ("[\"Càng học, chúng ta càng thấy mình còn thiếu sót.\", \"Chúng ta càng thấy mình còn thiếu sót càng học.\", \"Càng thấy mình thiếu sót chúng ta càng học.\"]", "Càng học, chúng ta càng thấy mình còn thiếu sót.", "Chọn cấu trúc so sánh tăng tiến:"),
                    ("[\"Chẳng những học giỏi mà Nam còn rất lễ phép.\", \"Học giỏi chẳng những mà Nam còn rất lễ phép.\", \"Nam còn rất lễ phép chẳng những học giỏi mà.\"]", "Chẳng những học giỏi mà Nam còn rất lễ phép.", "Chọn cặp quan hệ từ tăng cường:"),
                },
            };

            var result = new List<Question>();
            var bank = banks[diff];
            foreach (var item in bank)
            {
                result.Add(new Question
                {
                    GameId = gameId,
                    QuestionType = "multiple_choice",
                    Difficulty = diff,
                    Data = item.data,
                    Answer = item.answer,
                    Explanation = item.explanation,
                    IsActive = true,
                });
            }
            return result;
        }

        // =====================================================================
        // CHÍNH TẢ — fill_blank
        // =====================================================================
        private static List<Question> FillBlank(int gameId, int diff)
        {
            var banks = new Dictionary<int, List<(string data, string answer)>>
            {
                [1] = new()
                {
                    ("Con m..o kêu meo meo", "è"),
                    ("Bầu tr..i xanh biếc", "ờ"),
                    ("Em ..i học về", "đ"),
                    ("Hoa hồng m..u đỏ", "à"),
                    ("Trường h..c của em", "ọ"),
                    ("Nắng m..a vàng óng", "ặ"),
                },
                [2] = new()
                {
                    ("Tiếng Việt dùng hệ ch.. Latinh", "ữ"),
                    ("Chữ 'ng' là phụ âm g..p", "h"),
                    ("Dấu hỏi đặt tr..n chữ cái", "ê"),
                    ("Câu ghép gồm hai m..nh đề", "ệ"),
                    ("Từ đồng âm g..y hiểu nhầm", "â"),
                    ("Trạng ngữ đứng đ..u câu", "ầ"),
                },
                [3] = new()
                {
                    ("Phong cách ngôn ngữ khoa h..c", "ọ"),
                    ("Biện pháp tu từ nh..n hoá", "â"),
                    ("Sử dụng d..u chấm lửng đúng lúc", "ấ"),
                    ("Câu rút g..n thường thiếu chủ ngữ", "ọ"),
                    ("Liên kết c..u bằng phép nối", "â"),
                    ("Diễn đạt bóng b..y dùng ẩn dụ", "ẩ"),
                },
            };

            return MakeQuestions(gameId, "fill_blank", diff, banks[diff]);
        }

        // =====================================================================
        // NHÌN TRANH — picture_guess
        // =====================================================================
        private static List<Question> PictureGuess(int gameId, int diff)
        {
            var banks = new Dictionary<int, List<(string data, string answer, string? imgUrl)>>
            {
                [1] = new()
                {
                    ("Con vật này là gì?", "Con mèo", "https://loremflickr.com/320/240/cat,kitten,pet?lock=101"),
                    ("Con vật này là gì?", "Con chó", "https://loremflickr.com/320/240/dog,puppy,pet?lock=102"),
                    ("Đây là quả gì?", "Quả táo", "https://loremflickr.com/320/240/apple,fruit?lock=103"),
                    ("Đây là quả gì?", "Quả chuối", "https://loremflickr.com/320/240/banana,fruit?lock=104"),
                    ("Phương tiện này là gì?", "Xe đạp", "https://loremflickr.com/320/240/bicycle,cycling?lock=105"),
                    ("Phương tiện này là gì?", "Xe máy", "https://loremflickr.com/320/240/motorcycle,scooter?lock=106"),
                },
                [2] = new()
                {
                    ("Hình ảnh chim bồ câu biểu trưng cho?", "Hòa bình", "https://loremflickr.com/320/240/pigeon,white,bird?lock=107"),
                    ("Đây là loài cây biểu tượng của VN?", "Cây tre", "https://loremflickr.com/320/240/bamboo,plant?lock=108"),
                    ("Loài hoa này thường mọc ở đầm lầy?", "Hoa sen", "https://loremflickr.com/320/240/lotus,flower?lock=109"),
                    ("Địa danh nổi tiếng này ở Quảng Ninh?", "Vịnh Hạ Long", "https://loremflickr.com/320/240/halongbay,vietnam?lock=110"),
                    ("Nhạc cụ truyền thống VN?", "Đàn bầu", "https://loremflickr.com/320/240/instrument,vietnam?lock=111"),
                    ("Trang phục truyền thống của phụ nữ VN?", "Áo dài", "https://loremflickr.com/320/240/vietnamese,dress?lock=112"),
                },
                [3] = new()
                {
                    ("Tác phẩm văn học kinh điển này là?", "Truyện Kiều", "https://loremflickr.com/320/240/book?lock=13"),
                    ("Đại thi hào dân tộc này là ai?", "Nguyễn Du", "https://loremflickr.com/320/240/portrait?lock=14"),
                    ("Vùng đồng bằng lớn nhất miền Nam?", "Đồng bằng sông Cửu Long", "https://loremflickr.com/320/240/river?lock=15"),
                    ("Nơi yên nghỉ của Chủ tịch Hồ Chí Minh?", "Lăng Bác", "https://loremflickr.com/320/240/palace?lock=16"),
                    ("Ký hiệu này dùng để ngăn cách các vế câu?", "Dấu chấm phẩy", "https://loremflickr.com/320/240/ink?lock=17"),
                    ("Thể thơ truyền thống 6 chữ và 8 chữ?", "Thơ lục bát", "https://loremflickr.com/320/240/scroll?lock=18"),
                },
            };

            var result = new List<Question>();
            var bank = banks[diff];
            foreach (var item in bank)
            {
                result.Add(new Question
                {
                    GameId = gameId,
                    QuestionType = "picture_guess",
                    Difficulty = diff,
                    Data = item.data,
                    Answer = item.answer,
                    ImageUrl = item.imgUrl,
                    IsActive = true,
                });
            }
            return result;
        }

        // =====================================================================
        // VÙNG MIỀN — listen_choose
        // =====================================================================
        private static List<Question> ListenChoose(int gameId, int diff)
        {
            var banks = new Dictionary<int, List<(string data, string answer, string? audioUrl)>>
            {
                [1] = new()
                {
                    ("[\"Giọng Miền Bắc\", \"Giọng Miền Trung\", \"Giọng Miền Nam\"]", "Giọng Miền Bắc", GetWikiUrl("Vi-hanoi-m-chào.ogg")),
                    ("[\"Giọng Miền Bắc\", \"Giọng Miền Trung\", \"Giọng Miền Nam\"]", "Giọng Miền Nam", GetWikiUrl("Vi-Sài_Gòn-m-Cần_Giờ.ogg")),
                    ("[\"Chào buổi sáng\", \"Chào buổi trưa\", \"Chào buổi tối\"]", "Chào buổi sáng", GetWikiUrl("Vi-hanoi-m-mười.ogg")), // "mười" is Nord
                    ("[\"Giọng Bắc\", \"Giọng Nam\", \"Giọng Trung\"]", "Giọng Nam", GetWikiUrl("Vi-Sài_Gòn-f-Hoàng_Văn_Thụ.ogg")),
                    ("[\"Rất vui gặp bạn\", \"Hẹn gặp lại\", \"Tạm biệt\"]", "Rất vui gặp bạn", GetWikiUrl("Vi-hanoi-m-rất.ogg")),
                    ("[\"Người Việt Nam\", \"Người Hàn Quốc\", \"Người Trung Quốc\"]", "Người Việt Nam", GetWikiUrl("Vi-saigon-m-nói.ogg")), // Guessing
                },
                [2] = new()
                {
                    ("[\"Tôi là người Hà Nội\", \"Tôi là người Sài Gòn\", \"Tôi là người Huế\"]", "Tôi là người Hà Nội", GetWikiUrl("Vi-hanoi-m-nay.ogg")),
                    ("[\"Tôi là người Hà Nội\", \"Tôi là người Sài Gòn\", \"Tôi là người Huế\"]", "Tôi là người Sài Gòn", GetWikiUrl("Vi-Sài_Gòn-m-Cẩm_Mỹ.ogg")),
                    ("[\"Chúc mừng năm mới\", \"Chúc mừng sinh nhật\", \"Chúc mừng giáng sinh\"]", "Chúc mừng năm mới", GetWikiUrl("Vi-hanoi-m-vị.ogg")),
                    ("[\"Hẹn gặp lại các bạn\", \"Chào mừng các bạn\", \"Cảm ơn các bạn\"]", "Hẹn gặp lại các bạn", GetWikiUrl("Vi-hanoi-m-từ.ogg")),
                    ("[\"Trẻ em hôm nay\", \"Thế giới ngày mai\", \"Tình yêu thương\"]", "Trẻ em hôm nay", GetWikiUrl("Vi-hanoi-m-thay đổi.ogg")),
                    ("[\"Nam bộ\", \"Trung bộ\", \"Bắc bộ\"]", "Nam bộ", GetWikiUrl("Vi-Sài_Gòn-f-Châu_Thành.ogg")),
                },
                [3] = new()
                {
                    ("[\"Phát triển bền vững\", \"Kinh tế xanh\", \"Công nghệ số\"]", "Phát triển bền vững", GetWikiUrl("Vi-hanoi-m-nói.ogg")),
                    ("[\"Gìn giữ bản sắc\", \"Du lịch văn hóa\", \"Lễ hội truyền thống\"]", "Gìn giữ bản sắc", GetWikiUrl("Vi-Sài_Gòn-m-Cần_Giờ.ogg")),
                    ("[\"Hà Nội nghìn năm văn hiến\", \"Sài Gòn năng động\", \"Huế mộng mơ\"]", "Hà Nội nghìn năm văn hiến", GetWikiUrl("Vi-hanoi-m-mười.ogg")),
                    ("[\"Đoàn kết là sức mạnh\", \"Lá lành đùm lá rách\", \"Uống nước nhớ nguồn\"]", "Đoàn kết là sức mạnh", GetWikiUrl("Vi-saigon-m-vị.ogg")),
                    ("[\"Bản sắc dân tộc\", \"Hợp tác quốc tế\", \"Hội nhập kinh tế\"]", "Bản sắc dân tộc", GetWikiUrl("Vi-hanoi-m-thay đổi.ogg")),
                    ("[\"Bảo tồn di sản\", \"Di tích lịch sử\", \"Kỳ quan thiên nhiên\"]", "Bảo tồn di sản", GetWikiUrl("Vi-Sài_Gòn-f-Hoàng_Văn_Thụ.ogg")),
                },
            };

            var result = new List<Question>();
            var bank = banks[diff];
            foreach (var item in bank)
            {
                result.Add(new Question
                {
                    GameId = gameId,
                    QuestionType = "listen_choose",
                    Difficulty = diff,
                    Data = item.data,
                    Answer = item.answer,
                    AudioUrl = item.audioUrl,
                    Explanation = "Nghe và chọn đáp án chính xác:",
                    IsActive = true,
                });
            }
            return result;
        }

        // =====================================================================
        // XẾP CÂU — drag_drop_sentence
        // =====================================================================
        private static List<Question> DragDropSentence(int gameId, int diff)
        {
            var banks = new Dictionary<int, List<(string data, string answer)>>
            {
                [1] = new()
                {
                    ("[\"Em\", \"đi\", \"học\"]", "Em đi học"),
                    ("[\"Tôi\", \"yêu\", \"Việt Nam\"]", "Tôi yêu Việt Nam"),
                    ("[\"Mẹ\", \"nấu\", \"cơm\"]", "Mẹ nấu cơm"),
                    ("[\"Con\", \"mèo\", \"ngủ\"]", "Con mèo ngủ"),
                    ("[\"Bầu\", \"trời\", \"xanh\"]", "Bầu trời xanh"),
                    ("[\"Hoa\", \"nở\", \"rộ\"]", "Hoa nở rộ"),
                },
                [2] = new()
                {
                    ("[\"Tiếng Việt\", \"rất\", \"giàu\", \"thanh điệu\"]", "Tiếng Việt rất giàu thanh điệu"),
                    ("[\"Học sinh\", \"đang\", \"chăm chỉ\", \"học bài\"]", "Học sinh đang chăm chỉ học bài"),
                    ("[\"Mùa xuân\", \"đến\", \"ngàn hoa\", \"đua nở\"]", "Mùa xuân đến ngàn hoa đua nở"),
                    ("[\"Ông bà\", \"thường\", \"kể\", \"chuyện cổ\"]", "Ông bà thường kể chuyện cổ"),
                    ("[\"Bè bạn\", \"phải\", \"biết\", \"giúp đỡ\", \"nhau\"]", "Bè bạn phải biết giúp đỡ nhau"),
                    ("[\"Quê hương\", \"là\", \"chùm khế ngọt\", \"của em\"]", "Quê hương là chùm khế ngọt của em"),
                },
                [3] = new()
                {
                    ("[\"Văn học\", \"dân gian\", \"là\", \"túi khôn\", \"của\", \"nhân dân\"]", "Văn học dân gian là túi khôn của nhân dân"),
                    ("[\"Nguyễn Du\", \"đã\", \"để lại\", \"kiệt tác\", \"Truyện Kiều\"]", "Nguyễn Du đã để lại kiệt tác Truyện Kiều"),
                    ("[\"Biện pháp\", \"ẩn dụ\", \"làm\", \"tăng\", \"sức\", \"gợi hình\"]", "Biện pháp ẩn dụ làm tăng sức gợi hình"),
                    ("[\"Chúng ta\", \"cần\", \"bảo tồn\", \"di sản\", \"văn hóa\"]", "Chúng ta cần bảo tồn di sản văn hóa"),
                    ("[\"Tinh thần\", \"tự học\", \"là\", \"chìa khóa\", \"thành công\"]", "Tinh thần tự học là chìa khóa thành công"),
                    ("[\"Sách\", \"là\", \"kho tàng\", \"tri thức\", \"của\", \"loài người\"]", "Sách là kho tàng tri thức của loài người"),
                },
            };

            return MakeQuestions(gameId, "drag_drop_sentence", diff, banks[diff]);
        }

        // =====================================================================
        // ÔN TẬP — find_error (chọn từ sai trong câu)
        // =====================================================================
        private static List<Question> FindError(int gameId, int diff)
        {
            var banks = new Dictionary<int, List<(string data, string answer)>>
            {
                [1] = new()
                {
                    ("[\"Tôi\", \"ĐI\", \"trương\"]", "trương"),
                    ("[\"Con\", \"chó\", \"sứa\"]", "sứa"),
                    ("[\"Hôm\", \"nai\", \"đẹp\"]", "nai"),
                    ("[\"Em\", \"yêu\", \"quê\", \"hưong\"]", "hưong"),
                    ("[\"Bầu\", \"trời\", \"xang\"]", "xang"),
                    ("[\"Mẹ\", \"nấu\", \"com\"]", "com"),
                },
                [2] = new()
                {
                    ("[\"Bạn\", \"phải\", \"biếc\", \"vâng lời\"]", "biếc"),
                    ("[\"Tiếng\", \"Viêt\", \"rất\", \"trong sáng\"]", "Viêt"),
                    ("[\"Em\", \"thường\", \"xuyên\", \"độp\", \"sách\"]", "độp"),
                    ("[\"Mùa\", \"xuân\", \"hoa\", \"đào\", \"nỡ\"]", "nỡ"),
                    ("[\"Dòng\", \"sông\", \"chảy\", \"hien\", \"hòa\"]", "hien"),
                    ("[\"Mặt\", \"trời\", \"mộc\", \"ở\", \"đằng đông\"]", "mộc"),
                },
                [3] = new()
                {
                    ("[\"Học\", \"tập\", \"là\", \"quyền\", \"lợi\", \"và\", \"nhiệm\", \"vụ\"]", "Học"), // Giả sử yêu cầu tìm từ viết hoa sai hoặc ngữ cảnh
                    ("[\"Công\", \"cha\", \"như\", \"núi\", \"Thái\", \"Sơng\"]", "Sơng"),
                    ("[\"Nghĩa\", \"mẹ\", \"như\", \"nước\", \"trong\", \" nguồn\", \"chảy\", \"ra\"]", " nguồn"), // Khoảng trắng dư
                    ("[\"Một\", \"con\", \"ngựa\", \"đau\", \"cả\", \"tàu\", \"bỏ\", \"cỏ\"]", "tàu"), // Ví dụ logic: tàu -> tàu? (sai vần)
                    ("[\"Ăn\", \"quả\", \"nhớ\", \"kẻ\", \"trồng\", \"cây\"]", "Ăn"), // Ví dụ tìm lỗi dấu
                    ("[\"Gần\", \"mực\", \"thì\", \"đen\", \"gần\", \"đèn\", \"thì\", \"sáng\"]", "Gần"), 
                },
            };
            // Cập nhật lại logic diff 3 cho rõ ràng hơn (sai chính tả tinh vi)
            banks[3] = new()
            {
                 ("[\"Yếu\", \"tố\", \"biểu\", \"cãm\", \"trong\", \"văn\", \"bản\"]", "cãm"),
                 ("[\"Những\", \"câu\", \"thơ\", \"lọc\", \"bát\", \"ngọt\", \"ngào\"]", "lọc"),
                 ("[\"Biện\", \"pháp\", \"tu\", \"từ\", \"hoáng\", \"dụ\"]", "hoáng"),
                 ("[\"Phong\", \"cách\", \"ngôn\", \"ngữ\", \"nghệ\", \"thuộc\"]", "thuộc"),
                 ("[\"Sự\", \"nghiệp\", \"giáng\", \"dục\", \"con\", \"người\"]", "giáng"),
                 ("[\"Đoàn\", \"kết\", \"là\", \"sức\", \"mạnh\", \"vô\", \" điệc\"]", " điệc"),
            };

            return MakeQuestions(gameId, "find_error", diff, banks[diff]);
        }

        // =====================================================================
        // HELPER: turn bank into Question list
        // =====================================================================
        private static List<Question> MakeQuestions(int gameId, string type, int diff,
            List<(string data, string answer)> bank)
        {
            var result = new List<Question>();
            for (int i = 0; i < Math.Min(6, bank.Count); i++)
            {
                result.Add(new Question
                {
                    GameId       = gameId,
                    QuestionType = type,
                    Difficulty   = diff,
                    Data         = bank[i].data,
                    Answer       = bank[i].answer,
                    IsActive     = true,
                });
            }
            return result;
        }
    }
}
