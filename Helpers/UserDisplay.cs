using Microsoft.AspNetCore.Identity;

namespace DACS.Helpers
{
    /// <summary>
    /// Tên hiển thị công khai của người dùng (bình luận, chat).
    /// Tài khoản thường có UserName = Email nên chỉ hiện phần trước @, không lộ email;
    /// tài khoản có UserName riêng (họ tên) thì hiện UserName.
    /// </summary>
    public static class UserDisplay
    {
        public static string Name(IdentityUser? user, string fallback = "Người dùng")
        {
            if (user == null) return fallback;

            var userName = user.UserName?.Trim();
            if (!string.IsNullOrEmpty(userName) && !userName.Contains('@'))
                return userName;

            var email = user.Email ?? userName ?? string.Empty;
            var at = email.IndexOf('@');
            if (at > 0) return email[..at];
            return string.IsNullOrEmpty(email) ? fallback : email;
        }
    }
}
