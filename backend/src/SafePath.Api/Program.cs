using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using DotNetEnv;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using SafePath.Application;
using SafePath.Infrastructure;

var envPath = new[]
{
    ".env",
    Path.Combine("backend", ".env"),
    Path.Combine("..", ".env"),
    Path.Combine("..", "..", ".env"),
}.FirstOrDefault(File.Exists);

if (envPath is not null)
{
    Env.Load(envPath);
}

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    });
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

var supabaseUrl = builder.Configuration["Supabase:Url"]
    ?? throw new InvalidOperationException("Supabase:Url is not configured.");
var supabaseAudience = builder.Configuration["Supabase:Audience"] ?? "authenticated";
var supabaseIssuer = $"{supabaseUrl.TrimEnd('/')}/auth/v1";

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = supabaseIssuer;
        options.RequireHttpsMetadata = true;
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new()
        {
            ValidateIssuer = true,
            ValidIssuer = supabaseIssuer,
            ValidateAudience = true,
            ValidAudience = supabaseAudience,
            ValidateLifetime = true,
            NameClaimType = "sub",
            RoleClaimType = "role",
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });

builder.Services.AddAuthorization();

builder.Services.AddCors(options =>
{
    options.AddPolicy("SafePathClient", policy =>
    {
        policy
            .SetIsOriginAllowed(origin =>
            {
                if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri))
                {
                    return false;
                }

                return uri.Host is "localhost" or "127.0.0.1" ||
                    uri.Host.StartsWith("192.168.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("10.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.16.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.17.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.18.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.19.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.20.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.21.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.22.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.23.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.24.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.25.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.26.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.27.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.28.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.29.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.30.", StringComparison.Ordinal) ||
                    uri.Host.StartsWith("172.31.", StringComparison.Ordinal);
            })
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

builder.Services.AddRateLimiter(options =>
{
    // T-05-02: rate-limit /invites/redeem per-IP to blunt invite-code brute-forcing
    // (RESEARCH Pitfall 4). Partitioned by remote IP so one caller cannot exhaust the
    // budget for every other caller.
    options.AddPolicy("invite-redeem", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
            }));

    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseRateLimiter();

app.UseCors("SafePathClient");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();

// Exposes the implicit top-level-statements Program class to WebApplicationFactory<Program>
// in SafePath.Api.IntegrationTests.
public partial class Program
{
}
