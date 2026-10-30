using DACS.Data;
using DACS.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace DACS.Repositories
{
    public class PlaceRepository : IPlaceRepository
    {
        private const string MapCacheKey = "PlaceRepository_ApprovedForMap";
        private const string ListCacheKey = "PlaceRepository_ApprovedList";
        private static readonly TimeSpan MapCacheLifetime = TimeSpan.FromHours(1);

        private readonly ApplicationDbContext _context;
        private readonly IMemoryCache _cache;

        public PlaceRepository(ApplicationDbContext context, IMemoryCache cache)
        {
            _context = context;
            _cache = cache;
        }

        public void InvalidatePlaceCaches()
        {
            _cache.Remove(MapCacheKey);
            _cache.Remove(ListCacheKey);
        }

        public async Task<IEnumerable<Place>> GetAllAsync()
        {
            return await _context.Places
                .Include(p => p.Categories)
                .ToListAsync();
        }

        public async Task<IEnumerable<PlaceMapDto>> GetApprovedForMapAsync()
        {
            // Trang chủ cần toàn bộ địa điểm và truy vấn tới Supabase mất 1-2 giây, nên giữ trong RAM.
            // Mọi thay đổi qua repository sẽ xóa cache; sửa trực tiếp DB thì tối đa 1 giờ mới cập nhật.
            if (_cache.TryGetValue(MapCacheKey, out List<PlaceMapDto>? cached) && cached != null)
                return cached;

            // Chỉ truy vấn đúng các cột bản đồ cần, không kéo theo cache AI của toàn bộ địa điểm
            var places = await _context.Places
                .AsNoTracking()
                .Where(p => p.IsApproved)
                .Select(p => new PlaceMapDto
                {
                    Id = p.Id,
                    Name = p.Name,
                    Address = p.Address,
                    Latitude = p.Latitude,
                    Longitude = p.Longitude,
                    Description = p.Description,
                    ImageUrl = p.ImageUrl,
                    PhoneNumber = p.PhoneNumber,
                    PriceRange = p.PriceRange,
                    BannerUrl = p.BannerUrl,
                    BannerStatus = p.BannerStatus,
                    StarRating = p.StarRating,
                    Amenities = p.Amenities,
                    CategorySlugs = p.Categories.Select(c => c.Slug).ToList()
                })
                .ToListAsync();

            _cache.Set(MapCacheKey, places, MapCacheLifetime);
            return places;
        }

        public async Task<IReadOnlyList<PlaceListItemDto>> GetApprovedListAsync()
        {
            if (_cache.TryGetValue(ListCacheKey, out List<PlaceListItemDto>? cached) && cached != null)
                return cached;

            var places = await _context.Places
                .AsNoTracking()
                .Where(p => p.IsApproved)
                .OrderByDescending(p => p.BannerStatus == BannerStatus.Active)
                .ThenByDescending(p => p.StarRating ?? 0)
                .Select(p => new PlaceListItemDto
                {
                    Id = p.Id,
                    Name = p.Name,
                    Address = p.Address,
                    Latitude = p.Latitude,
                    Longitude = p.Longitude,
                    Description = p.Description,
                    ImageUrl = p.ImageUrl,
                    PhoneNumber = p.PhoneNumber,
                    PriceRange = p.PriceRange,
                    BannerUrl = p.BannerUrl,
                    BannerStatus = (int)p.BannerStatus,
                    StarRating = p.StarRating,
                    Amenities = p.Amenities,
                    Categories = p.Categories.Select(c => new PlaceListCategoryDto
                    {
                        Id = c.Id,
                        Name = c.Name,
                        Slug = c.Slug,
                        Icon = c.Icon
                    }).ToList()
                })
                .ToListAsync();

            _cache.Set(ListCacheKey, places, MapCacheLifetime);
            return places;
        }

        public async Task<IEnumerable<Place>> GetByOwnerIdAsync(string ownerId)
        {
            return await _context.Places
                .Include(p => p.Categories)
                .Where(p => p.OwnerId == ownerId)
                .ToListAsync();
        }

        public async Task<Place?> GetByIdAsync(int id)
        {
            return await _context.Places
                .Include(p => p.Categories)
                .Include(p => p.Comments)
                    .ThenInclude(c => c.User)
                .Include(p => p.Images)
                .FirstOrDefaultAsync(p => p.Id == id);
        }

        public async Task AddAsync(Place place)
        {
            await _context.Places.AddAsync(place);
            await _context.SaveChangesAsync();
            InvalidatePlaceCaches();
        }

        public async Task UpdateAsync(Place place)
        {
            _context.Places.Update(place);
            await _context.SaveChangesAsync();
            InvalidatePlaceCaches();
        }

        public async Task DeleteAsync(int id)
        {
            var place = await _context.Places.FindAsync(id);
            if (place != null)
            {
                _context.Places.Remove(place);
                await _context.SaveChangesAsync();
                InvalidatePlaceCaches();
            }
        }
    }
}
