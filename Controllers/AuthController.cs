using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using DACS.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace DACS.Controllers
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        private readonly UserManager<IdentityUser> _userManager;
        private readonly SignInManager<IdentityUser> _signInManager;
        private readonly IConfiguration _configuration;
        private readonly OtpService _otpService;

        public AuthController(
            UserManager<IdentityUser> userManager,
            SignInManager<IdentityUser> signInManager,
            IConfiguration configuration,
            OtpService otpService)
        {
            _userManager = userManager;
            _signInManager = signInManager;
            _configuration = configuration;
            _otpService = otpService;
        }

        public class LoginRequest
        {
            public string Email { get; set; } = string.Empty;
            public string Password { get; set; } = string.Empty;
        }

        public class RegisterRequest
        {
            public string Email { get; set; } = string.Empty;
            public string Password { get; set; } = string.Empty;
            public string? Role { get; set; } = "Customer"; // Customer or Owner
        }

        public class VerifyOtpRequest
        {
            public string Email { get; set; } = string.Empty;
            public string Code { get; set; } = string.Empty;
        }

        public class ResendOtpRequest
        {
            public string Email { get; set; } = string.Empty;
        }

        // POST: /api/auth/login
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest model)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var user = await _userManager.FindByEmailAsync(model.Email);
            if (user == null)
            {
                return Unauthorized(new { success = false, message = "Email hoặc mật khẩu không đúng." });
            }

            var result = await _signInManager.CheckPasswordSignInAsync(user, model.Password, lockoutOnFailure: true);

            if (result.IsLockedOut)
            {
                return StatusCode(StatusCodes.Status423Locked, new { success = false, message = "Tài khoản của bạn đã bị tạm khoá do nhập sai nhiều lần." });
            }

            if (result.IsNotAllowed && await _otpService.HandleUnconfirmedLoginAsync(user, model.Password))
            {
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    success = false,
                    requiresOtp = true,
                    email = user.Email,
                    message = "Tài khoản chưa xác thực email. Vui lòng nhập mã OTP đã gửi tới hòm thư của bạn."
                });
            }

            if (!result.Succeeded)
            {
                return Unauthorized(new { success = false, message = "Email hoặc mật khẩu không đúng." });
            }

            var roles = await _userManager.GetRolesAsync(user);
            var (token, expiresAt) = GenerateJwtToken(user, roles);

            return Ok(new
            {
                success = true,
                token,
                expiresAt,
                user = new
                {
                    id = user.Id,
                    email = user.Email,
                    userName = user.UserName,
                    roles = roles.ToList()
                }
            });
        }

        // POST: /api/auth/register
        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterRequest model)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var existing = await _userManager.FindByEmailAsync(model.Email);
            if (existing != null)
            {
                return BadRequest(new { success = false, message = "Email này đã được sử dụng." });
            }

            var user = new IdentityUser
            {
                UserName = model.Email,
                Email = model.Email
            };

            var result = await _userManager.CreateAsync(user, model.Password);
            if (!result.Succeeded)
            {
                var errors = string.Join("; ", result.Errors.Select(e => e.Description));
                return BadRequest(new { success = false, message = errors });
            }

            string roleToAssign = string.Equals(model.Role, "Owner", StringComparison.OrdinalIgnoreCase) ? "Owner" : "Customer";
            await _userManager.AddToRoleAsync(user, roleToAssign);

            // Giống web: phải xác thực email bằng OTP rồi mới được cấp token
            await _otpService.SendAsync(user);

            return Ok(new
            {
                success = true,
                requiresOtp = true,
                email = user.Email,
                message = "Đăng ký thành công. Vui lòng nhập mã OTP đã gửi tới email để kích hoạt tài khoản."
            });
        }

        // POST: /api/auth/verify-otp
        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpRequest model)
        {
            var user = await _userManager.FindByEmailAsync(model.Email);
            if (user == null || user.EmailConfirmed)
                return BadRequest(new { success = false, message = OtpService.Describe(OtpVerifyStatus.Expired) });

            var status = await _otpService.VerifyAsync(user, model.Code);
            if (status != OtpVerifyStatus.Success)
                return BadRequest(new { success = false, message = OtpService.Describe(status) });

            var roles = await _userManager.GetRolesAsync(user);
            var (token, expiresAt) = GenerateJwtToken(user, roles);

            return Ok(new
            {
                success = true,
                message = "Xác thực email thành công.",
                token,
                expiresAt,
                user = new
                {
                    id = user.Id,
                    email = user.Email,
                    userName = user.UserName,
                    roles = roles.ToList()
                }
            });
        }

        // POST: /api/auth/resend-otp
        [HttpPost("resend-otp")]
        public async Task<IActionResult> ResendOtp([FromBody] ResendOtpRequest model)
        {
            var user = await _userManager.FindByEmailAsync(model.Email);

            // Không tiết lộ email có tồn tại/đã xác thực hay chưa
            if (user != null && !user.EmailConfirmed)
            {
                var wait = _otpService.GetResendWaitSeconds(user);
                if (wait > 0)
                    return StatusCode(StatusCodes.Status429TooManyRequests,
                        new { success = false, retryAfterSeconds = wait, message = $"Vui lòng chờ {wait} giây trước khi gửi lại mã OTP." });

                await _otpService.SendAsync(user);
            }

            return Ok(new { success = true, message = "Nếu tài khoản cần xác thực, mã OTP mới đã được gửi tới email." });
        }

        // GET: /api/auth/me
        [Authorize]
        [HttpGet("me")]
        public async Task<IActionResult> GetCurrentUser()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
                return NotFound(new { success = false, message = "Không tìm thấy người dùng." });

            var roles = await _userManager.GetRolesAsync(user);

            return Ok(new
            {
                success = true,
                user = new
                {
                    id = user.Id,
                    email = user.Email,
                    userName = user.UserName,
                    roles = roles.ToList()
                }
            });
        }

        private (string token, DateTime expiresAt) GenerateJwtToken(IdentityUser user, IList<string> roles)
        {
            var jwtSettings = _configuration.GetSection("Jwt");
            // Program.cs đã kiểm tra Key khi khởi động
            var keyStr = jwtSettings["Key"]!;
            var issuer = jwtSettings["Issuer"] ?? "RestNDineApi";
            var audience = jwtSettings["Audience"] ?? "RestNDineClient";
            var expireDays = int.TryParse(jwtSettings["ExpireDays"], out var d) ? d : 30;

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(keyStr));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new List<Claim>
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.Id),
                new Claim(ClaimTypes.NameIdentifier, user.Id),
                new Claim(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
                new Claim(ClaimTypes.Name, user.UserName ?? user.Email ?? string.Empty),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            foreach (var role in roles)
            {
                claims.Add(new Claim(ClaimTypes.Role, role));
            }

            var expiresAt = DateTime.UtcNow.AddDays(expireDays);

            var token = new JwtSecurityToken(
                issuer: issuer,
                audience: audience,
                claims: claims,
                expires: expiresAt,
                signingCredentials: creds
            );

            return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
        }
    }
}
