using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.UI.Services;
using Microsoft.Extensions.Caching.Memory;

namespace DACS.Services
{
    public enum OtpVerifyStatus
    {
        Success,
        Invalid,
        Expired,
        TooManyAttempts
    }

    /// <summary>
    /// OTP xác thực email dùng chung cho trang Identity (web) và API (mobile).
    /// - Mã 6 số sinh bằng RandomNumberGenerator
    /// - Hết hạn sau 10 phút, tối đa 5 lần nhập sai cho mỗi mã
    /// - Gửi lại phải cách nhau tối thiểu 60 giây
    /// </summary>
    public class OtpService
    {
        public const int MaxAttempts = 5;
        private static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(10);
        private static readonly TimeSpan ResendCooldown = TimeSpan.FromSeconds(60);

        private readonly UserManager<IdentityUser> _userManager;
        private readonly IMemoryCache _cache;
        private readonly IEmailSender _emailSender;
        private readonly IWebHostEnvironment _env;
        private readonly ILogger<OtpService> _logger;

        public OtpService(
            UserManager<IdentityUser> userManager,
            IMemoryCache cache,
            IEmailSender emailSender,
            IWebHostEnvironment env,
            ILogger<OtpService> logger)
        {
            _userManager = userManager;
            _cache = cache;
            _emailSender = emailSender;
            _env = env;
            _logger = logger;
        }

        private sealed class OtpEntry
        {
            public required string Code { get; init; }
            public required string ConfirmToken { get; init; }
            public DateTime SentAt { get; init; }
            public int FailedAttempts; // tăng bằng Interlocked để request song song không vượt giới hạn
        }

        private static string CacheKey(string userId) => $"OTP_EmailConf_{userId}";

        /// <summary>
        /// Số giây còn phải chờ trước khi được gửi lại OTP (0 = gửi được ngay).
        /// </summary>
        public int GetResendWaitSeconds(IdentityUser user)
        {
            if (_cache.TryGetValue(CacheKey(user.Id), out OtpEntry? entry) && entry != null)
            {
                var wait = entry.SentAt + ResendCooldown - DateTime.UtcNow;
                if (wait > TimeSpan.Zero) return (int)Math.Ceiling(wait.TotalSeconds);
            }
            return 0;
        }

        /// <summary>Tạo mã mới (thay mã cũ) và gửi qua email.</summary>
        public async Task SendAsync(IdentityUser user)
        {
            var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
            var entry = new OtpEntry
            {
                Code = code,
                ConfirmToken = await _userManager.GenerateEmailConfirmationTokenAsync(user),
                SentAt = DateTime.UtcNow
            };
            _cache.Set(CacheKey(user.Id), entry, Lifetime);

            if (_env.IsDevelopment())
                _logger.LogWarning(">>> [DEV] OTP cho {Email}: {Otp} <<<", user.Email, code);

            await _emailSender.SendEmailAsync(
                user.Email!,
                "📡 Mã xác thực OTP tài khoản RestNDine của bạn",
                EmailTemplateHelper.GetOtpEmailHtml(code, user.Email!));
        }

        /// <summary>Kiểm tra mã; đúng thì xác nhận email của user.</summary>
        public async Task<OtpVerifyStatus> VerifyAsync(IdentityUser user, string? code)
        {
            var key = CacheKey(user.Id);
            if (!_cache.TryGetValue(key, out OtpEntry? entry) || entry == null)
                return OtpVerifyStatus.Expired;

            if (Volatile.Read(ref entry.FailedAttempts) >= MaxAttempts)
                return OtpVerifyStatus.TooManyAttempts;

            var expected = Encoding.UTF8.GetBytes(entry.Code);
            var actual = Encoding.UTF8.GetBytes(code?.Trim() ?? string.Empty);
            if (!CryptographicOperations.FixedTimeEquals(expected, actual))
            {
                return Interlocked.Increment(ref entry.FailedAttempts) >= MaxAttempts
                    ? OtpVerifyStatus.TooManyAttempts
                    : OtpVerifyStatus.Invalid;
            }

            var result = await _userManager.ConfirmEmailAsync(user, entry.ConfirmToken);
            if (!result.Succeeded)
            {
                _logger.LogWarning("ConfirmEmailAsync thất bại cho {UserId}: {Errors}",
                    user.Id, string.Join("; ", result.Errors.Select(e => e.Description)));
                return OtpVerifyStatus.Expired;
            }

            _cache.Remove(key);
            return OtpVerifyStatus.Success;
        }

        /// <summary>
        /// Dùng khi đăng nhập trả về NotAllowed. Identity kiểm tra "đã xác thực email" TRƯỚC mật khẩu,
        /// nên ở đây phải tự kiểm tra mật khẩu (có tính lockout) trước khi gửi OTP.
        /// Trả về true nếu mật khẩu đúng và email chưa xác thực → client chuyển sang bước nhập OTP.
        /// </summary>
        public async Task<bool> HandleUnconfirmedLoginAsync(IdentityUser user, string password)
        {
            if (user.EmailConfirmed || await _userManager.IsLockedOutAsync(user))
                return false;

            if (!await _userManager.CheckPasswordAsync(user, password))
            {
                await _userManager.AccessFailedAsync(user);
                return false;
            }

            if (GetResendWaitSeconds(user) == 0)
                await SendAsync(user);
            return true;
        }

        public static string Describe(OtpVerifyStatus status) => status switch
        {
            OtpVerifyStatus.Invalid => "Mã OTP không chính xác. Vui lòng kiểm tra lại.",
            OtpVerifyStatus.Expired => "Mã OTP đã hết hạn hoặc không tồn tại. Vui lòng bấm gửi lại.",
            OtpVerifyStatus.TooManyAttempts => $"Bạn đã nhập sai quá {MaxAttempts} lần. Vui lòng bấm gửi lại để nhận mã mới.",
            _ => string.Empty
        };
    }
}
