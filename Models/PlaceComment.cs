using Microsoft.AspNetCore.Identity;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DACS.Models
{
    public class PlaceComment
    {
        public int Id { get; set; }

        [Required]
        public string Content { get; set; } = string.Empty;

        /// <summary>Đánh giá sao: 1–5</summary>
        [Range(1, 5)]
        public int Rating { get; set; } = 5;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        /// <summary>Số lượt bình chọn "Hữu ích" từ cộng đồng.</summary>
        public int HelpfulCount { get; set; } = 0;

        [Required]
        public int PlaceId { get; set; }

        [ForeignKey("PlaceId")]
        public virtual Place? Place { get; set; }

        [Required]
        public string UserId { get; set; } = string.Empty;

        [ForeignKey("UserId")]
        public virtual IdentityUser? User { get; set; }
    }
}
