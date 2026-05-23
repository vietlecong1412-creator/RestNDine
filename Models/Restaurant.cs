using System.ComponentModel.DataAnnotations;

namespace DACS.Models
{
    public class Restaurant
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

        public string? PriceRange { get; set; }

        public string? BannerUrl { get; set; }

        public string? PaymentProofUrl { get; set; }

        public BannerStatus BannerStatus { get; set; } = BannerStatus.None;

        public bool IsApproved { get; set; } = false;

        public bool IsCafe { get; set; } = false;

        public string? OwnerId { get; set; }

        [System.ComponentModel.DataAnnotations.Schema.ForeignKey("OwnerId")]
        public Microsoft.AspNetCore.Identity.IdentityUser? Owner { get; set; }

        public virtual ICollection<Comment> Comments { get; set; } = new List<Comment>();

        public virtual ICollection<RestaurantImage> Images { get; set; } = new List<RestaurantImage>();
    }
}
