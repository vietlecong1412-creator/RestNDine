using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Identity;

namespace DACS.Models
{
    public class Place
    {
        public int Id { get; set; }

        [Required]
        public string Name { get; set; } = string.Empty;

        public string? Address { get; set; }

        public double Latitude { get; set; }

        public double Longitude { get; set; }

        public string? Description { get; set; }

        public string? ImageUrl { get; set; }

        public string? PhoneNumber { get; set; }

        public string? PriceRange { get; set; }

        public string? BannerUrl { get; set; }

        public string? PaymentProofUrl { get; set; }

        public BannerStatus BannerStatus { get; set; } = BannerStatus.None;

        public bool IsApproved { get; set; } = false;

        // ── Categories (many-to-many) ──
        public virtual ICollection<PlaceCategory> Categories { get; set; } = new List<PlaceCategory>();

        // ── Fields chỉ dành cho Khách sạn (nullable) ──

        [Range(1, 5)]
        public int? StarRating { get; set; }

        public string? Amenities { get; set; }

        // ── Thông tin bổ sung ──
        // VD: "T2-T6: 10:00–22:00 | T7-CN: 09:00–23:00"
        public string? OpeningHours { get; set; }

        public string? Website { get; set; }

        // JSON array string: ["Có WiFi","Bãi đỗ xe","Phù hợp gia đình"]
        public string? Tags { get; set; }

        // ── AI Summary Cache ──
        /// <summary>HTML tóm tắt AI đã biên dịch, được lưu cache để tăng tốc độ tải trang.</summary>
        public string? AiSummaryCache { get; set; }

        /// <summary>Thời điểm cache AI được tạo/cập nhật lần cuối.</summary>
        public DateTime? AiSummaryCacheUpdatedAt { get; set; }

        // ── Owner ──
        public string? OwnerId { get; set; }

        [ForeignKey("OwnerId")]
        public virtual IdentityUser? Owner { get; set; }

        // ── Navigation ──
        public virtual ICollection<PlaceComment> Comments { get; set; } = new List<PlaceComment>();

        public virtual ICollection<PlaceImage> Images { get; set; } = new List<PlaceImage>();
    }
}
