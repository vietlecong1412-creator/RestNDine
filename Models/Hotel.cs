using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Identity;

namespace DACS.Models
{
    public class Hotel
    {
        public int Id { get; set; }

        [Required]
        public string Name { get; set; }

        public string Address { get; set; }

        public double Latitude { get; set; }

        public double Longitude { get; set; }

        public string Description { get; set; }

        public string? ImageUrl { get; set; }

        public string? PhoneNumber { get; set; }

        public string? PriceRange { get; set; } // e.g., "500.000đ - 2.000.000đ"

        [Range(1, 5)]
        public int StarRating { get; set; } = 3; // Số sao khách sạn (1-5 sao)

        public string? Amenities { get; set; } // e.g., "Free Wifi, Hồ bơi, Máy lạnh, Chỗ đỗ xe, Buffet"

        public string? BannerUrl { get; set; }

        public string? PaymentProofUrl { get; set; }

        public BannerStatus BannerStatus { get; set; } = BannerStatus.None;

        public bool IsApproved { get; set; } = false;

        public string? OwnerId { get; set; }

        [System.ComponentModel.DataAnnotations.Schema.ForeignKey("OwnerId")]
        public IdentityUser? Owner { get; set; }

        public virtual ICollection<HotelComment> Comments { get; set; } = new List<HotelComment>();

        public virtual ICollection<HotelImage> Images { get; set; } = new List<HotelImage>();
    }
}
