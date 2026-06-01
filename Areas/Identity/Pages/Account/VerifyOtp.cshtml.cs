#nullable disable
using System;
using System.ComponentModel.DataAnnotations;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.UI.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Caching.Memory;

namespace DACS.Areas.Identity.Pages.Account
{
    [AllowAnonymous]
    public class VerifyOtpModel : PageModel
    {
        private readonly UserManager<IdentityUser> _userManager;
        private readonly IMemoryCache _memoryCache;
        private readonly IEmailSender _emailSender;

        public VerifyOtpModel(
            UserManager<IdentityUser> userManager, 
            IMemoryCache memoryCache, 
            IEmailSender emailSender)
        {
            _userManager = userManager;
            _memoryCache = memoryCache;
            _emailSender = emailSender;
        }

        [BindProperty]
        public InputModel Input { get; set; }

        public string Email { get; set; }
        public string UserId { get; set; }

        public class InputModel
        {
            [Required(ErrorMessage = "Vui lòng nhập mã OTP.")]
            [StringLength(6, MinimumLength = 6, ErrorMessage = "Mã OTP phải gồm đúng 6 chữ số.")]
            [RegularExpression(@"^[0-9]+$", ErrorMessage = "Mã OTP chỉ được chứa các chữ số.")]
            public string OtpCode { get; set; }

            [Required]
            public string UserId { get; set; }
        }

        public async Task<IActionResult> OnGetAsync(string userId, string email)
        {
            if (userId == null || email == null)
            {
                return RedirectToPage("/Index");
            }

            Email = email;
            UserId = userId;

            Input = new InputModel
            {
                UserId = userId
            };

            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            var user = await _userManager.FindByIdAsync(Input.UserId);
            if (user == null)
            {
                return NotFound($"Không tìm thấy tài khoản người dùng.");
            }

            Email = user.Email;
            UserId = user.Id;

            if (!ModelState.IsValid)
            {
                return Page();
            }

            var cacheKey = $"OTP_EmailConf_{Input.UserId}";
            if (_memoryCache.TryGetValue(cacheKey, out string cachedOtp))
            {
                if (cachedOtp == Input.OtpCode)
                {
                    // OTP đúng! Lấy cryptographic token để xác thực với Identity
                    var tokenKey = $"CryptoToken_EmailConf_{Input.UserId}";
                    if (_memoryCache.TryGetValue(tokenKey, out string cryptoToken))
                    {
                        var result = await _userManager.ConfirmEmailAsync(user, cryptoToken);
                        if (result.Succeeded)
                        {
                            // Dọn dẹp cache
                            _memoryCache.Remove(cacheKey);
                            _memoryCache.Remove(tokenKey);

                            TempData["Success"] = "🎉 Tài khoản đã được xác thực thành công! Hãy đăng nhập để tiếp tục.";
                            return RedirectToPage("./Login");
                        }
                        
                        foreach (var error in result.Errors)
                        {
                            ModelState.AddModelError(string.Empty, error.Description);
                        }
                    }
                    else
                    {
                        ModelState.AddModelError(string.Empty, "Mã token bảo mật đã hết hạn. Vui lòng nhấn gửi lại OTP.");
                    }
                }
                else
                {
                    ModelState.AddModelError(string.Empty, "Mã OTP không chính xác. Vui lòng kiểm tra lại.");
                }
            }
            else
            {
                ModelState.AddModelError(string.Empty, "Mã OTP đã hết hạn hoặc không tồn tại. Vui lòng bấm gửi lại.");
            }

            return Page();
        }

        public async Task<IActionResult> OnPostResendOtpAsync(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound();

            // Tạo mới OTP
            var otpCode = new Random().Next(100000, 999999).ToString();
            var cacheKey = $"OTP_EmailConf_{userId}";
            _memoryCache.Set(cacheKey, otpCode, TimeSpan.FromMinutes(10));

            // Tạo cryptographic token
            var cryptoToken = await _userManager.GenerateEmailConfirmationTokenAsync(user);
            _memoryCache.Set($"CryptoToken_EmailConf_{userId}", cryptoToken, TimeSpan.FromMinutes(10));

            // Gửi email mới
            var emailBody = DACS.Services.EmailTemplateHelper.GetOtpEmailHtml(otpCode, user.Email);
            await _emailSender.SendEmailAsync(
                user.Email,
                "📡 Mã xác thực OTP tài khoản RestNDine của bạn",
                emailBody);

            TempData["Success"] = "Đã gửi lại mã OTP mới vào hòm thư của bạn!";
            return RedirectToPage("./VerifyOtp", new { userId = user.Id, email = user.Email });
        }
    }
}
