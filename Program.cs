using System.Text;
using DACS.Data;
using DACS.Repositories;
using DACS.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

// Trên Windows, log ghi ra file sẽ mất dấu tiếng Việt nếu giữ bảng mã mặc định của hệ thống
Console.OutputEncoding = Encoding.UTF8;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddIdentity<IdentityUser, IdentityRole>(options =>
{
    // Cấu hình Email Confirmation
    options.SignIn.RequireConfirmedAccount = true;

    // Cấu hình Lockout Policy (Khóa tài khoản nếu nhập sai nhiều lần)
    options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
    options.Lockout.MaxFailedAccessAttempts = 5;
    options.Lockout.AllowedForNewUsers = true;
})
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultUI()
    .AddDefaultTokenProviders();

// Configure JWT Authentication
var jwtSettings = builder.Configuration.GetSection("Jwt");
// Key lấy từ User Secrets (dev) hoặc biến môi trường Jwt__Key (production) — không có giá trị mặc định
var keyStr = jwtSettings["Key"];
if (string.IsNullOrWhiteSpace(keyStr) || Encoding.UTF8.GetByteCount(keyStr) < 32)
    throw new InvalidOperationException("Thiếu cấu hình Jwt:Key (tối thiểu 32 byte). Đặt bằng 'dotnet user-secrets set Jwt:Key <giá trị>' hoặc biến môi trường Jwt__Key.");
var key = Encoding.UTF8.GetBytes(keyStr);

builder.Services.AddAuthentication()
    .AddJwtBearer(JwtBearerDefaults.AuthenticationScheme, options =>
    {
        options.SaveToken = true;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(key),
            ValidateIssuer = true,
            ValidIssuer = jwtSettings["Issuer"] ?? "RestNDineApi",
            ValidateAudience = true,
            ValidAudience = jwtSettings["Audience"] ?? "RestNDineClient",
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero
        };

        // Cho phép nhận token từ SignalR query string (?access_token=...)
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/chatHub"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

// Authorization policy supporting both Cookies and JWT
builder.Services.AddAuthorization(options =>
{
    var defaultPolicy = new AuthorizationPolicyBuilder(
        JwtBearerDefaults.AuthenticationScheme,
        IdentityConstants.ApplicationScheme)
        .RequireAuthenticatedUser()
        .Build();
    options.DefaultPolicy = defaultPolicy;
});

// Configure CORS for Flutter client (Mobile/Web/Desktop)
builder.Services.AddCors(options =>
{
    // App mobile không gửi header Origin nên không bị ảnh hưởng; Flutter web khi dev chạy ở localhost với cổng ngẫu nhiên
    var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
    bool isDevelopment = builder.Environment.IsDevelopment();

    options.AddPolicy("ClientApps", policy =>
    {
        policy.SetIsOriginAllowed(origin =>
                  allowedOrigins.Contains(origin, StringComparer.OrdinalIgnoreCase)
                  || (isDevelopment && Uri.TryCreate(origin, UriKind.Absolute, out var uri) && uri.IsLoopback))
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

builder.Services.AddTransient<Microsoft.AspNetCore.Identity.UI.Services.IEmailSender, EmailSender>();

builder.Services.AddRazorPages();
builder.Services.AddMemoryCache();
builder.Services.AddSignalR();

builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
    options.Providers.Add<Microsoft.AspNetCore.ResponseCompression.BrotliCompressionProvider>();
    options.Providers.Add<Microsoft.AspNetCore.ResponseCompression.GzipCompressionProvider>();
    options.MimeTypes = Microsoft.AspNetCore.ResponseCompression.ResponseCompressionDefaults.MimeTypes
        .Concat(new[] { "application/json" });
});

builder.Services.AddScoped<IPlaceRepository, PlaceRepository>();
builder.Services.AddScoped<IAiSummaryService, LocalAiSummaryService>();
builder.Services.AddScoped<DACS.Services.VnPayService>();
builder.Services.AddScoped<OtpService>();
builder.Services.AddScoped<BannerPaymentService>();
builder.Services.AddScoped<PlaceReviewService>();

builder.Services.AddControllersWithViews()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
    });

// Register Swagger Generators with JWT support
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new Microsoft.OpenApi.OpenApiInfo
    { 
        Title = "RestNDine API", 
        Version = "v1",
        Description = "API documentation for the RestNDine Restaurant and Hotel Map Application"
    });
});

builder.Services.Configure<RequestLocalizationOptions>(options =>
{
    var supportedCultures = new[] { new System.Globalization.CultureInfo("en-US") };
    options.DefaultRequestCulture = new Microsoft.AspNetCore.Localization.RequestCulture("en-US");
    options.SupportedCultures = supportedCultures;
    options.SupportedUICultures = supportedCultures;
});

var app = builder.Build();

// wwwroot và script AI được tìm theo thư mục hiện tại, nên cố định về content root dù chạy từ đâu
Directory.SetCurrentDirectory(app.Environment.ContentRootPath);

// Chỉ bật khi chạy sau reverse proxy (Render/Railway...), vì nếu không có proxy thì client có thể tự giả các header này.
// ForwardLimit = 1: chỉ tin giá trị do proxy gần nhất thêm vào, bỏ qua phần client tự gửi.
if (app.Configuration.GetValue<bool>("ReverseProxy:Enabled"))
{
    var forwardedHeaders = new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
        ForwardLimit = 1
    };
    // IP của proxy trên nền tảng hosting thay đổi nên không khai báo trước được
    forwardedHeaders.KnownIPNetworks.Clear();
    forwardedHeaders.KnownProxies.Clear();
    app.UseForwardedHeaders(forwardedHeaders);
}

app.UseResponseCompression();

// Swagger chỉ dùng khi phát triển, không để lộ danh sách API trên production
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "RestNDine API v1");
        c.RoutePrefix = "swagger";
    });
}

app.UseRequestLocalization();

using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;

    var roleManager = services.GetRequiredService<RoleManager<IdentityRole>>();
    var userManager = services.GetRequiredService<UserManager<IdentityUser>>();
    var context = services.GetRequiredService<ApplicationDbContext>();

    // Gọi hàm Seed dữ liệu mẫu thực tế từ Google Maps
    await DbInitializer.SeedDataAsync(userManager, roleManager, context,
        app.Environment, app.Configuration, app.Logger);

    // Làm nóng cache để người mở trang chủ đầu tiên cũng không phải chờ truy vấn
    var placeRepository = services.GetRequiredService<IPlaceRepository>();
    await placeRepository.GetApprovedForMapAsync();
    await placeRepository.GetApprovedListAsync();
}

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseRouting();
app.UseCors("ClientApps");

app.UseAuthentication();
app.UseAuthorization();

app.MapStaticAssets();

app.MapControllerRoute(
    name: "areas",
    pattern: "{area:exists}/{controller=Home}/{action=Index}/{id?}"
);

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}")
    .WithStaticAssets();

app.MapControllers();
app.MapRazorPages();
app.MapHub<DACS.Hubs.ChatHub>("/chatHub");
app.Run();
