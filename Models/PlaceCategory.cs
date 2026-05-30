namespace DACS.Models
{
    public class PlaceCategory
    {
        public int Id { get; set; }

        /// <summary>Tên hiển thị: "Nhà hàng", "Khách sạn", "Quán cà phê"</summary>
        public string Name { get; set; } = string.Empty;

        /// <summary>Slug dùng cho icon/logic: "restaurant", "hotel", "cafe"</summary>
        public string Slug { get; set; } = string.Empty;

        /// <summary>Icon emoji đại diện cho loại</summary>
        public string Icon { get; set; } = "📍";

        public virtual ICollection<Place> Places { get; set; } = new List<Place>();
    }
}
