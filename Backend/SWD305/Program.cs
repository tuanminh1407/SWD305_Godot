using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi;
using Microsoft.OpenApi.Models; 
using SWD305.Models;
using SWD305.Security;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<VnegSystemContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection")
    ));

// Add services to the container.

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler =
            System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
    });

builder.Services.Configure<Microsoft.AspNetCore.Http.Features.FormOptions>(options =>
{
    options.MultipartBodyLengthLimit = 50 * 1024 * 1024; // 50MB
});

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        In = ParameterLocation.Header,
        Description = "Please enter a valid token",
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        BearerFormat = "JWT",
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
{
    {
        new OpenApiSecurityScheme
        {
            Reference = new OpenApiReference
            {
                Type = ReferenceType.SecurityScheme,
                Id = "Bearer"
            }
        },
        new string[] {}
    }
});
});

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = "SessionToken";
    options.DefaultChallengeScheme = "SessionToken";
}).AddScheme<Microsoft.AspNetCore.Authentication.AuthenticationSchemeOptions, SWD305.Security.SessionTokenAuthHandler>("SessionToken", null);

builder.Services.AddAuthorization();

var app = builder.Build();

// Seed a demo account for local development so the Godot client can log in immediately.
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var context = scope.ServiceProvider.GetRequiredService<VnegSystemContext>();

    try
    {
        const string demoEmail = "demo@vneg.local";
        const string demoPassword = "123456";

        var exists = await context.Users.AnyAsync(u => u.Email == demoEmail);
        if (!exists)
        {
            var now = DateTime.Now;
            var user = new User
            {
                Email = demoEmail,
                Phone = null,
                Grade = 1,
                Region = null, // avoid DB CHECK constraint surprises
                AvatarUrl = null,
                Role = "user",
                IsActive = true,
                PasswordHash = PasswordHashing.HashPassword(demoPassword),
                CreatedAt = now,
                UpdatedAt = now
            };

            context.Users.Add(user);
            await context.SaveChangesAsync();

            context.Profiles.Add(new Profile { UserId = user.Id });
            await context.SaveChangesAsync();

            app.Logger.LogInformation("Seeded demo user: {Email} / {Password}", demoEmail, demoPassword);
        }
        else
        {
            app.Logger.LogInformation("Demo user already exists: {Email}", demoEmail);
        }
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning(ex, "Failed to seed demo user (non-fatal).");
    }
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

//app.UseHttpsRedirection();

app.UseStaticFiles();
app.UseCors("AllowFrontend");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
