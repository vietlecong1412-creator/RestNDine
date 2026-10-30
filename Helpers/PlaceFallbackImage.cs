using DACS.Models;

namespace DACS.Helpers
{
    /// <summary>
    /// Ảnh minh hoạ theo loại địa điểm, dùng khi địa điểm không có ảnh hoặc link ảnh đã hết hạn.
    /// Cùng quy tắc chọn ảnh với placeFallback() ở trang chủ và fallbackImageUrl trong app Flutter.
    /// </summary>
    public static class PlaceFallbackImage
    {
        public static string Url(Place place)
        {
            var slugs = place.Categories.Select(c => c.Slug).ToList();
            var type = slugs.Contains("hotel") ? "hotel" : slugs.Contains("cafe") ? "cafe" : "restaurant";
            return $"/images/fallback/{type}-{place.Id % 4 + 1}.jpg";
        }
    }
}
