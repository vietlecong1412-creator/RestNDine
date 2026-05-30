using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Identity;

namespace DACS.Models
{
    /// <summary>
    /// Lưu lịch sử bình chọn "Hữu ích" của từng user cho từng bình luận.
    /// Composite PK (CommentId + UserId) đảm bảo mỗi user chỉ vote 1 lần/bình luận ở tầng DB.
    /// </summary>
    public class CommentHelpfulVote
    {
        [Required]
        public int CommentId { get; set; }

        [ForeignKey("CommentId")]
        public virtual PlaceComment? Comment { get; set; }

        [Required]
        public string UserId { get; set; } = string.Empty;

        [ForeignKey("UserId")]
        public virtual IdentityUser? User { get; set; }

        public DateTime VotedAt { get; set; } = DateTime.Now;
    }
}
