namespace DACS.Models
{
    public class PlaceMapDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Address { get; set; }
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public string? Description { get; set; }
        public string? ImageUrl { get; set; }
        public string? PhoneNumber { get; set; }
        public string? PriceRange { get; set; }
        public string? BannerUrl { get; set; }
        public BannerStatus BannerStatus { get; set; }
        public List<string> CategorySlugs { get; set; } = new List<string>();
        public int? StarRating { get; set; }
        public string? Amenities { get; set; }
    }
}
