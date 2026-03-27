using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;

namespace SWD305.Models;

public partial class VnegSystemContext : DbContext
{
    public VnegSystemContext()
    {
    }

    public VnegSystemContext(DbContextOptions<VnegSystemContext> options)
        : base(options)
    {
    }

    public virtual DbSet<Game> Games { get; set; }

    public virtual DbSet<GameError> GameErrors { get; set; }

    public virtual DbSet<GameErrorGrammar> GameErrorGrammars { get; set; }

    public virtual DbSet<GameSession> GameSessions { get; set; }

    public virtual DbSet<Grade> Grades { get; set; }

    public virtual DbSet<GrammarTopic> GrammarTopics { get; set; }

    public virtual DbSet<Map> Maps { get; set; }

    public virtual DbSet<Profile> Profiles { get; set; }

    public virtual DbSet<Question> Questions { get; set; }

    public virtual DbSet<QuestionGrammar> QuestionGrammars { get; set; }

    public virtual DbSet<Report> Reports { get; set; }

    public virtual DbSet<Session> Sessions { get; set; }

    public virtual DbSet<SystemLog> SystemLogs { get; set; }

    public virtual DbSet<Task> Tasks { get; set; }

    public virtual DbSet<TaskProgress> TaskProgresses { get; set; }

    public virtual DbSet<Team> Teams { get; set; }

    public virtual DbSet<TeamMember> TeamMembers { get; set; }

    public virtual DbSet<User> Users { get; set; }

    public virtual DbSet<UserGrammarProgress> UserGrammarProgresses { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Game>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__games__3213E83FF83A19AC");

            entity.ToTable("games");

            entity.HasIndex(e => new { e.MapId, e.OrderIndex }, "games_index_3");

            entity.HasIndex(e => e.GameType, "games_index_4");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Flow).HasColumnName("flow");
            entity.Property(e => e.GameType)
                .HasMaxLength(50)
                .HasColumnName("game_type");
            entity.Property(e => e.IsPremium)
                .HasDefaultValue(false)
                .HasColumnName("is_premium");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.MapId).HasColumnName("map_id");
            entity.Property(e => e.Name)
                .HasMaxLength(255)
                .HasColumnName("name");
            entity.Property(e => e.OrderIndex).HasColumnName("order_index");

            entity.HasOne(d => d.Map).WithMany(p => p.Games)
                .HasForeignKey(d => d.MapId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__games__map_id__60A75C0F");
        });

        modelBuilder.Entity<GameError>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__game_err__3213E83F0EC48632");

            entity.ToTable("game_errors");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.ErrorType)
                .HasMaxLength(255)
                .HasColumnName("error_type");
            entity.Property(e => e.GameSessionId).HasColumnName("game_session_id");
            entity.Property(e => e.QuestionId).HasColumnName("question_id");

            entity.HasOne(d => d.GameSession).WithMany(p => p.GameErrors)
                .HasForeignKey(d => d.GameSessionId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__game_erro__game___7C4F7684");

            entity.HasOne(d => d.Question).WithMany(p => p.GameErrors)
                .HasForeignKey(d => d.QuestionId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__game_erro__quest__7D439ABD");
        });

        modelBuilder.Entity<GameErrorGrammar>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__game_err__3213E83FE80EA038");

            entity.ToTable("game_error_grammar");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.GameErrorId).HasColumnName("game_error_id");
            entity.Property(e => e.GrammarTopicId).HasColumnName("grammar_topic_id");

            entity.HasOne(d => d.GameError).WithMany(p => p.GameErrorGrammars)
                .HasForeignKey(d => d.GameErrorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__game_erro__game___00200768");

            entity.HasOne(d => d.GrammarTopic).WithMany(p => p.GameErrorGrammars)
                .HasForeignKey(d => d.GrammarTopicId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__game_erro__gramm__01142BA1");
        });

        modelBuilder.Entity<GameSession>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__game_ses__3213E83F139D7E7B");

            entity.ToTable("game_sessions");

            entity.HasIndex(e => new { e.UserId, e.CompletedAt }, "game_sessions_index_11");

            entity.HasIndex(e => e.GameId, "game_sessions_index_12");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Accuracy)
                .HasColumnType("decimal(5, 2)")
                .HasColumnName("accuracy");
            entity.Property(e => e.Coins).HasColumnName("coins");
            entity.Property(e => e.CompletedAt)
                .HasColumnType("datetime")
                .HasColumnName("completed_at");
            entity.Property(e => e.GameId).HasColumnName("game_id");
            entity.Property(e => e.Score).HasColumnName("score");
            entity.Property(e => e.Stars).HasColumnName("stars");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.Game).WithMany(p => p.GameSessions)
                .HasForeignKey(d => d.GameId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__game_sess__game___797309D9");

            entity.HasOne(d => d.User).WithMany(p => p.GameSessions)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__game_sess__user___787EE5A0");
        });

        modelBuilder.Entity<Grade>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__grades__3213E83FB5F6723E");

            entity.ToTable("grades");

            entity.Property(e => e.Id)
                .ValueGeneratedNever()
                .HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(255)
                .HasColumnName("name");
        });

        modelBuilder.Entity<GrammarTopic>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__grammar___3213E83F057ACC2A");

            entity.ToTable("grammar_topics");

            entity.HasIndex(e => e.Code, "UQ__grammar___357D4CF9DA7990B0").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Code)
                .HasMaxLength(255)
                .HasColumnName("code");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.Difficulty).HasColumnName("difficulty");
            entity.Property(e => e.Example).HasColumnName("example");
            entity.Property(e => e.GradeMax).HasColumnName("grade_max");
            entity.Property(e => e.GradeMin).HasColumnName("grade_min");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.Name)
                .HasMaxLength(255)
                .HasColumnName("name");
            entity.Property(e => e.ParentId).HasColumnName("parent_id");

            entity.HasOne(d => d.Parent).WithMany(p => p.InverseParent)
                .HasForeignKey(d => d.ParentId)
                .HasConstraintName("FK__grammar_t__paren__693CA210");
        });

        modelBuilder.Entity<Map>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__maps__3213E83FCE2D15B1");

            entity.ToTable("maps");

            entity.HasIndex(e => new { e.GradeId, e.OrderIndex }, "maps_index_2");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.GradeId).HasColumnName("grade_id");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.Name)
                .HasMaxLength(255)
                .HasColumnName("name");
            entity.Property(e => e.OrderIndex).HasColumnName("order_index");

            entity.HasOne(d => d.Grade).WithMany(p => p.Maps)
                .HasForeignKey(d => d.GradeId)
                .HasConstraintName("FK__maps__grade_id__5BE2A6F2");
        });

        modelBuilder.Entity<Profile>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__profiles__3213E83FBBF737DF");

            entity.ToTable("profiles");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Badges).HasColumnName("badges");
            entity.Property(e => e.GrammarTree).HasColumnName("grammar_tree");
            entity.Property(e => e.TopErrors).HasColumnName("top_errors");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.WeeklyGraph).HasColumnName("weekly_graph");

            entity.HasOne(d => d.User).WithMany(p => p.Profiles)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__profiles__user_i__52593CB8");
        });

        modelBuilder.Entity<Question>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__question__3213E83F3890E2F1");

            entity.ToTable("questions");

            entity.HasIndex(e => e.GameId, "questions_index_5");

            entity.HasIndex(e => e.QuestionType, "questions_index_6");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Data).HasColumnName("data");
            entity.Property(e => e.Difficulty).HasColumnName("difficulty");
            entity.Property(e => e.Explanation).HasColumnName("explanation");
            entity.Property(e => e.GameId).HasColumnName("game_id");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.QuestionType)
                .HasMaxLength(255)
                .HasColumnName("question_type");

            entity.HasOne(d => d.Game).WithMany(p => p.Questions)
                .HasForeignKey(d => d.GameId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__questions__game___6477ECF3");
        });

        modelBuilder.Entity<QuestionGrammar>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__question__3213E83F46D12EEC");

            entity.ToTable("question_grammar");

            entity.HasIndex(e => e.GrammarTopicId, "question_grammar_index_8");

            entity.HasIndex(e => new { e.QuestionId, e.GrammarTopicId }, "uq_question_grammar").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.GrammarTopicId).HasColumnName("grammar_topic_id");
            entity.Property(e => e.QuestionId).HasColumnName("question_id");
            entity.Property(e => e.Weight)
                .HasDefaultValue(1)
                .HasColumnName("weight");

            entity.HasOne(d => d.GrammarTopic).WithMany(p => p.QuestionGrammars)
                .HasForeignKey(d => d.GrammarTopicId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__question___gramm__6EF57B66");

            entity.HasOne(d => d.Question).WithMany(p => p.QuestionGrammars)
                .HasForeignKey(d => d.QuestionId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__question___quest__6E01572D");
        });

        modelBuilder.Entity<Report>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__reports__3213E83F61C8B4C1");

            entity.ToTable("reports");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.ResolvedAt)
                .HasColumnType("datetime")
                .HasColumnName("resolved_at");
            entity.Property(e => e.ResolvedBy).HasColumnName("resolved_by");
            entity.Property(e => e.Status)
                .HasMaxLength(50)
                .HasColumnName("status");
            entity.Property(e => e.Type)
                .HasMaxLength(50)
                .HasColumnName("type");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.ResolvedByNavigation).WithMany(p => p.ReportResolvedByNavigations)
                .HasForeignKey(d => d.ResolvedBy)
                .HasConstraintName("FK__reports__resolve__1F98B2C1");

            entity.HasOne(d => d.User).WithMany(p => p.ReportUsers)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__reports__user_id__1EA48E88");
        });

        modelBuilder.Entity<Session>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__sessions__3213E83FCAF4888F");

            entity.ToTable("sessions");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.ExpiresAt)
                .HasColumnType("datetime")
                .HasColumnName("expires_at");
            entity.Property(e => e.JwtToken).HasColumnName("jwt_token");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithMany(p => p.Sessions)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__sessions__user_i__5629CD9C");
        });

        modelBuilder.Entity<SystemLog>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__system_l__3213E83F5B2318FF");

            entity.ToTable("system_logs");

            entity.HasIndex(e => new { e.UserId, e.CreatedAt }, "system_logs_index_16");

            entity.HasIndex(e => e.Action, "system_logs_index_17");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Action)
                .HasMaxLength(255)
                .HasColumnName("action");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.Details).HasColumnName("details");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithMany(p => p.SystemLogs)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__system_lo__user___236943A5");
        });

        modelBuilder.Entity<Task>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__tasks__3213E83F6E746B35");

            entity.ToTable("tasks");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.Criteria).HasColumnName("criteria");
            entity.Property(e => e.DueDate)
                .HasColumnType("datetime")
                .HasColumnName("due_date");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.Reward).HasColumnName("reward");
            entity.Property(e => e.TeamId).HasColumnName("team_id");
            entity.Property(e => e.Type)
                .HasMaxLength(50)
                .HasColumnName("type");
            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.Tasks)
                .HasForeignKey(d => d.CreatedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__tasks__created_b__14270015");

            entity.HasOne(d => d.Team).WithMany(p => p.Tasks)
                .HasForeignKey(d => d.TeamId)
                .HasConstraintName("FK__tasks__team_id__1332DBDC");
        });

        modelBuilder.Entity<TaskProgress>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__task_pro__3213E83F17A10986");

            entity.ToTable("task_progress");

            entity.HasIndex(e => new { e.UserId, e.Status }, "task_progress_index_15");

            entity.HasIndex(e => new { e.TaskId, e.UserId }, "uq_task_progress").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CompletedAt)
                .HasColumnType("datetime")
                .HasColumnName("completed_at");
            entity.Property(e => e.CurrentProgress).HasColumnName("current_progress");
            entity.Property(e => e.Status)
                .HasMaxLength(50)
                .HasColumnName("status");
            entity.Property(e => e.TargetValue).HasColumnName("target_value");
            entity.Property(e => e.TaskId).HasColumnName("task_id");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.Task).WithMany(p => p.TaskProgresses)
                .HasForeignKey(d => d.TaskId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__task_prog__task___18EBB532");

            entity.HasOne(d => d.User).WithMany(p => p.TaskProgresses)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__task_prog__user___19DFD96B");
        });

        modelBuilder.Entity<Team>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__teams__3213E83F6543467F");

            entity.ToTable("teams");

            entity.HasIndex(e => e.InviteCode, "UQ__teams__C90895D46042436D").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.InviteCode)
                .HasMaxLength(255)
                .HasColumnName("invite_code");
            entity.Property(e => e.Name)
                .HasMaxLength(255)
                .HasColumnName("name");
            entity.Property(e => e.OwnerId).HasColumnName("owner_id");

            entity.HasOne(d => d.Owner).WithMany(p => p.Teams)
                .HasForeignKey(d => d.OwnerId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__teams__owner_id__05D8E0BE");
        });

        modelBuilder.Entity<TeamMember>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__team_mem__3213E83F648A97A4");

            entity.ToTable("team_members");

            entity.HasIndex(e => new { e.TeamId, e.UserId }, "uq_team_member").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.JoinDate)
                .HasColumnType("datetime")
                .HasColumnName("join_date");
            entity.Property(e => e.Role)
                .HasMaxLength(50)
                .HasDefaultValue("member")
                .HasColumnName("role");
            entity.Property(e => e.TeamId).HasColumnName("team_id");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.Team).WithMany(p => p.TeamMembers)
                .HasForeignKey(d => d.TeamId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__team_memb__team___0B91BA14");

            entity.HasOne(d => d.User).WithMany(p => p.TeamMembers)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__team_memb__user___0C85DE4D");
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__users__3213E83FD698BEDE");

            entity.ToTable("users");

            entity.HasIndex(e => e.Email, "UQ__users__AB6E6164299DD780").IsUnique();

            entity.HasIndex(e => new { e.Grade, e.Region }, "users_index_0");

            entity.HasIndex(e => e.Role, "users_index_1");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.AvatarUrl)
                .HasMaxLength(255)
                .HasColumnName("avatar_url");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.Email)
                .HasMaxLength(255)
                .HasColumnName("email");
            entity.Property(e => e.Grade).HasColumnName("grade");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.PasswordHash)
                .HasMaxLength(255)
                .HasColumnName("password_hash");
            entity.Property(e => e.Phone)
                .HasMaxLength(255)
                .HasColumnName("phone");
            entity.Property(e => e.Region)
                .HasMaxLength(50)
                .HasColumnName("region");
            entity.Property(e => e.Role)
                .HasMaxLength(50)
                .HasDefaultValue("user")
                .HasColumnName("role");
            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("updated_at");
        });

        modelBuilder.Entity<UserGrammarProgress>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__user_gra__3213E83FDBDDE9B4");

            entity.ToTable("user_grammar_progress");

            entity.HasIndex(e => new { e.UserId, e.GrammarTopicId }, "uq_user_grammar").IsUnique();

            entity.HasIndex(e => e.MasteryLevel, "user_grammar_progress_index_10");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CorrectCount)
                .HasDefaultValue(0)
                .HasColumnName("correct_count");
            entity.Property(e => e.GrammarTopicId).HasColumnName("grammar_topic_id");
            entity.Property(e => e.LastPracticedAt)
                .HasColumnType("datetime")
                .HasColumnName("last_practiced_at");
            entity.Property(e => e.MasteryLevel)
                .HasColumnType("decimal(5, 2)")
                .HasColumnName("mastery_level");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.WrongCount)
                .HasDefaultValue(0)
                .HasColumnName("wrong_count");

            entity.HasOne(d => d.GrammarTopic).WithMany(p => p.UserGrammarProgresses)
                .HasForeignKey(d => d.GrammarTopicId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__user_gram__gramm__75A278F5");

            entity.HasOne(d => d.User).WithMany(p => p.UserGrammarProgresses)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__user_gram__user___74AE54BC");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
