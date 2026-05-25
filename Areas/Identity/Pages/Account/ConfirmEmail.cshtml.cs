#nullable disable
using System;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.WebUtilities;

namespace DACS.Areas.Identity.Pages.Account
{
    [AllowAnonymous]
    public class ConfirmEmailModel : PageModel
    {
        private readonly UserManager<IdentityUser> _userManager;

        public ConfirmEmailModel(UserManager<IdentityUser> userManager)
        {
            _userManager = userManager;
        }

        [TempData]
        public string StatusMessage { get; set; }

        public bool Succeeded { get; set; }

        public string UserEmail { get; set; }

        public async Task<IActionResult> OnGetAsync(string userId, string code)
        {
            if (userId == null || code == null)
            {
                return RedirectToPage("/Index");
            }

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
            {
                return NotFound($"Unable to load user with ID '{userId}'.");
            }

            UserEmail = user.Email;

            // Nếu email đã được xác nhận sẵn (ví dụ: đã được OTP xử lý thành công trước đó)
            if (await _userManager.IsEmailConfirmedAsync(user))
            {
                Succeeded = true;
                StatusMessage = "Cảm ơn bạn đã xác nhận email.";
                return Page();
            }

            try
            {
                var decodedCode = Encoding.UTF8.GetString(WebEncoders.Base64UrlDecode(code));
                var result = await _userManager.ConfirmEmailAsync(user, decodedCode);
                
                Succeeded = result.Succeeded;
                StatusMessage = Succeeded ? "Cảm ơn bạn đã xác nhận email." : "Lỗi khi xác nhận email.";
            }
            catch (Exception)
            {
                Succeeded = false;
                StatusMessage = "Mã xác nhận không hợp lệ hoặc đã hết hạn.";
            }

            return Page();
        }
    }
}
