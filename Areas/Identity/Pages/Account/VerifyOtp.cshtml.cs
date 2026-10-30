#nullable disable
using System.ComponentModel.DataAnnotations;
using System.Threading.Tasks;
using DACS.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace DACS.Areas.Identity.Pages.Account
{
    [AllowAnonymous]
    public class VerifyOtpModel : PageModel
    {
        private readonly UserManager<IdentityUser> _userManager;
        private readonly OtpService _otpService;

        public VerifyOtpModel(
            UserManager<IdentityUser> userManager,
            OtpService otpService)
        {
            _userManager = userManager;
            _otpService = otpService;
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

            if (user.EmailConfirmed)
            {
                TempData["Success"] = "Tài khoản đã được xác thực trước đó. Hãy đăng nhập để tiếp tục.";
                return RedirectToPage("./Login");
            }

            var status = await _otpService.VerifyAsync(user, Input.OtpCode);
            if (status == OtpVerifyStatus.Success)
            {
                TempData["Success"] = "🎉 Tài khoản đã được xác thực thành công! Hãy đăng nhập để tiếp tục.";
                return RedirectToPage("./Login");
            }

            ModelState.AddModelError(string.Empty, OtpService.Describe(status));
            return Page();
        }

        public async Task<IActionResult> OnPostResendOtpAsync(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound();

            if (user.EmailConfirmed)
            {
                TempData["Success"] = "Tài khoản đã được xác thực trước đó. Hãy đăng nhập để tiếp tục.";
                return RedirectToPage("./Login");
            }

            var wait = _otpService.GetResendWaitSeconds(user);
            if (wait > 0)
            {
                TempData["Error"] = $"Vui lòng chờ {wait} giây trước khi gửi lại mã OTP.";
            }
            else
            {
                await _otpService.SendAsync(user);
                TempData["Success"] = "Đã gửi lại mã OTP mới vào hòm thư của bạn!";
            }

            return RedirectToPage("./VerifyOtp", new { userId = user.Id, email = user.Email });
        }
    }
}
