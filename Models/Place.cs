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

        // ── Category (bắt buộc) ──
        public int CategoryId { get; set; }

        [ForeignKey("CategoryId")]
        public virtual PlaceCategory? Category { get; set; }

        // ── Fields chỉ dành cho Khách sạn (nullable) ──

        /// <summary>Số sao khách sạn (1-5). Chỉ dùng khi CategoryId = Hotel.</summary>
        [Range(1, 5)]
        public int? StarRating { get; set; }

        /// <summary>Tiện ích khách sạn, VD: "Free Wifi, Hồ bơi, Buffet". Chỉ dùng khi CategoryId = Hotel.</summary>
        public string? Amenities { get; set; }

        // ── Owner ──
        public string? OwnerId { get; set; }

        [ForeignKey("OwnerId")]
        public virtual IdentityUser? Owner { get; set; }

        // ── Navigation ──
        public virtual ICollection<PlaceComment> Comments { get; set; } = new List<PlaceComment>();

        public virtual ICollection<PlaceImage> Images { get; set; } = new List<PlaceImage>();
    }
}
