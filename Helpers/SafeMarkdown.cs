using System.Net;
using System.Text;

namespace DACS.Helpers
{
    /// <summary>
    /// Chuyển văn bản tóm tắt AI (markdown đơn giản) sang HTML an toàn.
    /// Nội dung được encode HTML trước, sau đó mới thay **đậm** và xuống dòng,
    /// nên câu trích từ bình luận người dùng không thể chèn thẻ/script vào trang.
    /// </summary>
    public static class SafeMarkdown
    {
        public static string ToHtml(string? txt)
        {
            if (string.IsNullOrEmpty(txt)) return "";

            var parts = WebUtility.HtmlEncode(txt).Split("**");
            var sb = new StringBuilder();
            for (int i = 0; i < parts.Length; i++)
            {
                if (i % 2 == 1) sb.Append("<strong>").Append(parts[i]).Append("</strong>");
                else sb.Append(parts[i]);
            }
            return sb.ToString().Replace("\n", "<br/>");
        }
    }
}
