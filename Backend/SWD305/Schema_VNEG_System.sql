-- =============================================
-- VNEG_System - Schema script (run in SSMS)
-- Chạy khi đã chọn database VNEG_System (USE VNEG_System hoặc chọn DB trong SSMS)
-- =============================================

USE VNEG_System;
GO

-- 1. grades (PK không identity - ValueGeneratedNever)
IF OBJECT_ID('dbo.grades', 'U') IS NULL
CREATE TABLE dbo.grades (
    id INT NOT NULL PRIMARY KEY,
    name NVARCHAR(255) NULL
);

-- 2. users
IF OBJECT_ID('dbo.users', 'U') IS NULL
CREATE TABLE dbo.users (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    email NVARCHAR(255) NOT NULL,
    phone NVARCHAR(255) NULL,
    password_hash NVARCHAR(255) NOT NULL,
    avatar_url NVARCHAR(255) NULL,
    grade INT NULL,
    region NVARCHAR(50) NULL,
    role NVARCHAR(50) NULL DEFAULT 'user',
    is_active BIT NULL DEFAULT 1,
    created_at DATETIME NULL DEFAULT GETDATE(),
    updated_at DATETIME NULL DEFAULT GETDATE(),
    CONSTRAINT UQ__users__email UNIQUE (email)
);

-- 3. profiles
IF OBJECT_ID('dbo.profiles', 'U') IS NULL
CREATE TABLE dbo.profiles (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    user_id INT NOT NULL,
    grammar_tree NVARCHAR(MAX) NULL,
    top_errors NVARCHAR(MAX) NULL,
    badges NVARCHAR(MAX) NULL,
    weekly_graph NVARCHAR(MAX) NULL,
    CONSTRAINT FK__profiles__user_i__52593CB8 FOREIGN KEY (user_id) REFERENCES dbo.users(id)
);

-- 4. sessions
IF OBJECT_ID('dbo.sessions', 'U') IS NULL
CREATE TABLE dbo.sessions (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    user_id INT NOT NULL,
    jwt_token NVARCHAR(MAX) NOT NULL,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NULL DEFAULT GETDATE(),
    CONSTRAINT FK__sessions__user_i__5629CD9C FOREIGN KEY (user_id) REFERENCES dbo.users(id)
);

-- 5. maps
IF OBJECT_ID('dbo.maps', 'U') IS NULL
CREATE TABLE dbo.maps (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    grade_id INT NULL,
    name NVARCHAR(255) NOT NULL,
    order_index INT NULL,
    is_active BIT NULL DEFAULT 1,
    CONSTRAINT FK__maps__grade_id__5BE2A6F2 FOREIGN KEY (grade_id) REFERENCES dbo.grades(id)
);

-- 6. grammar_topics (self-ref parent_id)
IF OBJECT_ID('dbo.grammar_topics', 'U') IS NULL
CREATE TABLE dbo.grammar_topics (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    parent_id INT NULL,
    code NVARCHAR(255) NULL,
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX) NULL,
    example NVARCHAR(MAX) NULL,
    grade_min INT NULL,
    grade_max INT NULL,
    difficulty INT NULL,
    is_active BIT NULL DEFAULT 1,
    CONSTRAINT UQ__grammar___code UNIQUE (code),
    CONSTRAINT FK__grammar_t__paren__693CA210 FOREIGN KEY (parent_id) REFERENCES dbo.grammar_topics(id)
);

-- 7. games
IF OBJECT_ID('dbo.games', 'U') IS NULL
CREATE TABLE dbo.games (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    map_id INT NOT NULL,
    name NVARCHAR(255) NOT NULL,
    game_type NVARCHAR(50) NULL,
    flow NVARCHAR(MAX) NULL,
    order_index INT NULL,
    is_premium BIT NULL DEFAULT 0,
    CONSTRAINT FK__games__map_id__60A75C0F FOREIGN KEY (map_id) REFERENCES dbo.maps(id)
);

-- 8. questions
IF OBJECT_ID('dbo.questions', 'U') IS NULL
CREATE TABLE dbo.questions (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    game_id INT NOT NULL,
    question_type NVARCHAR(255) NOT NULL,
    difficulty INT NULL,
    data NVARCHAR(MAX) NOT NULL,
    answer NVARCHAR(MAX) NOT NULL,
    image_url NVARCHAR(MAX) NULL,
    audio_url NVARCHAR(MAX) NULL,
    explanation NVARCHAR(MAX) NULL,
    is_active BIT NULL DEFAULT 1,
    CONSTRAINT FK__questions__game___6477ECF3 FOREIGN KEY (game_id) REFERENCES dbo.games(id)
);

-- 9. game_sessions
IF OBJECT_ID('dbo.game_sessions', 'U') IS NULL
CREATE TABLE dbo.game_sessions (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    user_id INT NOT NULL,
    game_id INT NOT NULL,
    score INT NULL,
    stars INT NULL,
    coins INT NULL,
    accuracy DECIMAL(5,2) NULL,
    completed_at DATETIME NULL,
    CONSTRAINT FK__game_sess__user___787EE5A0 FOREIGN KEY (user_id) REFERENCES dbo.users(id),
    CONSTRAINT FK__game_sess__game___797309D9 FOREIGN KEY (game_id) REFERENCES dbo.games(id)
);

-- 10. game_errors
IF OBJECT_ID('dbo.game_errors', 'U') IS NULL
CREATE TABLE dbo.game_errors (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    game_session_id INT NOT NULL,
    question_id INT NOT NULL,
    error_type NVARCHAR(255) NULL,
    CONSTRAINT FK__game_erro__game___7C4F7684 FOREIGN KEY (game_session_id) REFERENCES dbo.game_sessions(id),
    CONSTRAINT FK__game_erro__quest__7D439ABD FOREIGN KEY (question_id) REFERENCES dbo.questions(id)
);

-- 11. question_grammar
IF OBJECT_ID('dbo.question_grammar', 'U') IS NULL
CREATE TABLE dbo.question_grammar (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    question_id INT NOT NULL,
    grammar_topic_id INT NOT NULL,
    weight INT NULL DEFAULT 1,
    CONSTRAINT uq_question_grammar UNIQUE (question_id, grammar_topic_id),
    CONSTRAINT FK__question___quest__6E01572D FOREIGN KEY (question_id) REFERENCES dbo.questions(id),
    CONSTRAINT FK__question___gramm__6EF57B66 FOREIGN KEY (grammar_topic_id) REFERENCES dbo.grammar_topics(id)
);

-- 12. game_error_grammar
IF OBJECT_ID('dbo.game_error_grammar', 'U') IS NULL
CREATE TABLE dbo.game_error_grammar (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    game_error_id INT NOT NULL,
    grammar_topic_id INT NOT NULL,
    CONSTRAINT FK__game_erro__game___00200768 FOREIGN KEY (game_error_id) REFERENCES dbo.game_errors(id),
    CONSTRAINT FK__game_erro__gramm__01142BA1 FOREIGN KEY (grammar_topic_id) REFERENCES dbo.grammar_topics(id)
);

-- 13. user_grammar_progress
IF OBJECT_ID('dbo.user_grammar_progress', 'U') IS NULL
CREATE TABLE dbo.user_grammar_progress (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    user_id INT NOT NULL,
    grammar_topic_id INT NOT NULL,
    correct_count INT NULL DEFAULT 0,
    wrong_count INT NULL DEFAULT 0,
    mastery_level DECIMAL(5,2) NULL,
    last_practiced_at DATETIME NULL,
    CONSTRAINT uq_user_grammar UNIQUE (user_id, grammar_topic_id),
    CONSTRAINT FK__user_gram__user___74AE54BC FOREIGN KEY (user_id) REFERENCES dbo.users(id),
    CONSTRAINT FK__user_gram__gramm__75A278F5 FOREIGN KEY (grammar_topic_id) REFERENCES dbo.grammar_topics(id)
);

-- 14. reports
IF OBJECT_ID('dbo.reports', 'U') IS NULL
CREATE TABLE dbo.reports (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    user_id INT NULL,
    type NVARCHAR(50) NULL,
    description NVARCHAR(MAX) NULL,
    status NVARCHAR(50) NULL,
    resolved_by INT NULL,
    resolved_at DATETIME NULL,
    CONSTRAINT FK__reports__user_id__1EA48E88 FOREIGN KEY (user_id) REFERENCES dbo.users(id),
    CONSTRAINT FK__reports__resolve__1F98B2C1 FOREIGN KEY (resolved_by) REFERENCES dbo.users(id)
);

-- 15. teams
IF OBJECT_ID('dbo.teams', 'U') IS NULL
CREATE TABLE dbo.teams (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    owner_id INT NOT NULL,
    name NVARCHAR(255) NULL,
    description NVARCHAR(MAX) NULL,
    invite_code NVARCHAR(255) NULL,
    created_at DATETIME NULL DEFAULT GETDATE(),
    CONSTRAINT UQ__teams__invite_code UNIQUE (invite_code),
    CONSTRAINT FK__teams__owner_id__05D8E0BE FOREIGN KEY (owner_id) REFERENCES dbo.users(id)
);

-- 16. team_members
IF OBJECT_ID('dbo.team_members', 'U') IS NULL
CREATE TABLE dbo.team_members (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    team_id INT NOT NULL,
    user_id INT NOT NULL,
    role NVARCHAR(50) NULL DEFAULT 'member',
    join_date DATETIME NULL,
    CONSTRAINT uq_team_member UNIQUE (team_id, user_id),
    CONSTRAINT FK__team_memb__team___0B91BA14 FOREIGN KEY (team_id) REFERENCES dbo.teams(id),
    CONSTRAINT FK__team_memb__user___0C85DE4D FOREIGN KEY (user_id) REFERENCES dbo.users(id)
);

-- 17. tasks
IF OBJECT_ID('dbo.tasks', 'U') IS NULL
CREATE TABLE dbo.tasks (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    created_by INT NOT NULL,
    team_id INT NULL,
    type NVARCHAR(50) NULL,
    criteria NVARCHAR(MAX) NULL,
    reward NVARCHAR(MAX) NULL,
    due_date DATETIME NULL,
    is_active BIT NULL DEFAULT 1,
    created_at DATETIME NULL DEFAULT GETDATE(),
    updated_at DATETIME NULL DEFAULT GETDATE(),
    CONSTRAINT FK__tasks__created_b__14270015 FOREIGN KEY (created_by) REFERENCES dbo.users(id),
    CONSTRAINT FK__tasks__team_id__1332DBDC FOREIGN KEY (team_id) REFERENCES dbo.teams(id)
);

-- 18. task_progress
IF OBJECT_ID('dbo.task_progress', 'U') IS NULL
CREATE TABLE dbo.task_progress (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    task_id INT NOT NULL,
    user_id INT NOT NULL,
    status NVARCHAR(50) NULL,
    current_progress INT NULL,
    target_value INT NULL,
    completed_at DATETIME NULL,
    CONSTRAINT uq_task_progress UNIQUE (task_id, user_id),
    CONSTRAINT FK__task_prog__task___18EBB532 FOREIGN KEY (task_id) REFERENCES dbo.tasks(id),
    CONSTRAINT FK__task_prog__user___19DFD96B FOREIGN KEY (user_id) REFERENCES dbo.users(id)
);

-- 19. system_logs
IF OBJECT_ID('dbo.system_logs', 'U') IS NULL
CREATE TABLE dbo.system_logs (
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    user_id INT NULL,
    action NVARCHAR(255) NULL,
    details NVARCHAR(MAX) NULL,
    created_at DATETIME NULL DEFAULT GETDATE(),
    CONSTRAINT FK__system_lo__user___236943A5 FOREIGN KEY (user_id) REFERENCES dbo.users(id)
);

-- Indexes (optional, giống EF)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'games_index_3' AND object_id = OBJECT_ID('dbo.games'))
    CREATE INDEX games_index_3 ON dbo.games(map_id, order_index);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'games_index_4' AND object_id = OBJECT_ID('dbo.games'))
    CREATE INDEX games_index_4 ON dbo.games(game_type);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'game_sessions_index_11' AND object_id = OBJECT_ID('dbo.game_sessions'))
    CREATE INDEX game_sessions_index_11 ON dbo.game_sessions(user_id, completed_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'game_sessions_index_12' AND object_id = OBJECT_ID('dbo.game_sessions'))
    CREATE INDEX game_sessions_index_12 ON dbo.game_sessions(game_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'maps_index_2' AND object_id = OBJECT_ID('dbo.maps'))
    CREATE INDEX maps_index_2 ON dbo.maps(grade_id, order_index);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'questions_index_5' AND object_id = OBJECT_ID('dbo.questions'))
    CREATE INDEX questions_index_5 ON dbo.questions(game_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'questions_index_6' AND object_id = OBJECT_ID('dbo.questions'))
    CREATE INDEX questions_index_6 ON dbo.questions(question_type);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'question_grammar_index_8' AND object_id = OBJECT_ID('dbo.question_grammar'))
    CREATE INDEX question_grammar_index_8 ON dbo.question_grammar(grammar_topic_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'user_grammar_progress_index_10' AND object_id = OBJECT_ID('dbo.user_grammar_progress'))
    CREATE INDEX user_grammar_progress_index_10 ON dbo.user_grammar_progress(mastery_level);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'task_progress_index_15' AND object_id = OBJECT_ID('dbo.task_progress'))
    CREATE INDEX task_progress_index_15 ON dbo.task_progress(user_id, status);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'system_logs_index_16' AND object_id = OBJECT_ID('dbo.system_logs'))
    CREATE INDEX system_logs_index_16 ON dbo.system_logs(user_id, created_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'system_logs_index_17' AND object_id = OBJECT_ID('dbo.system_logs'))
    CREATE INDEX system_logs_index_17 ON dbo.system_logs(action);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'users_index_0' AND object_id = OBJECT_ID('dbo.users'))
    CREATE INDEX users_index_0 ON dbo.users(grade, region);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'users_index_1' AND object_id = OBJECT_ID('dbo.users'))
    CREATE INDEX users_index_1 ON dbo.users(role);

PRINT 'Schema VNEG_System created successfully.';
GO
