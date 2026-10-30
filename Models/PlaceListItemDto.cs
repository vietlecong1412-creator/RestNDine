namespace DACS.Models
{
    /// <summary>Một dòng trong GET /api/places (app mobile).</summary>
    public class PlaceListItemDto
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
        public int BannerStatus { get; set; }
        public int? StarRating { get; set; }
        public string? Amenities { get; set; }
        public List<PlaceListCategoryDto> Categories { get; set; } = new();
    }

    public class PlaceListCategoryDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Slug { get; set; } = string.Empty;
        public string Icon { get; set; } = string.Empty;
    }
}
