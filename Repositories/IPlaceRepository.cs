using DACS.Models;

namespace DACS.Repositories
{
    public interface IPlaceRepository
    {
        Task<IEnumerable<Place>> GetAllAsync();
        Task<IEnumerable<PlaceMapDto>> GetApprovedForMapAsync();
        Task<IReadOnlyList<PlaceListItemDto>> GetApprovedListAsync();
        Task<IEnumerable<Place>> GetByOwnerIdAsync(string ownerId);
        Task<Place?> GetByIdAsync(int id);
        Task AddAsync(Place place);
        Task UpdateAsync(Place place);
        Task DeleteAsync(int id);

        /// <summary>Xóa cache danh sách địa điểm khi dữ liệu bị đổi ngoài repository.</summary>
        void InvalidatePlaceCaches();
    }
}
