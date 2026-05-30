using DACS.Models;

namespace DACS.Repositories
{
    public interface IPlaceRepository
    {
        Task<IEnumerable<Place>> GetAllAsync();
        Task<IEnumerable<Place>> GetApprovedOnlyAsync();
        Task<IEnumerable<Place>> GetByCategoryAsync(int categoryId);
        Task<IEnumerable<Place>> GetByOwnerIdAsync(string ownerId);
        Task<Place?> GetByIdAsync(int id);
        Task AddAsync(Place place);
        Task UpdateAsync(Place place);
        Task DeleteAsync(int id);
    }
}
