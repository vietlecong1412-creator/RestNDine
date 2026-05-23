using DACS.Models;

namespace DACS.Repositories
{
    public interface IRestaurantRepository
    {
        Task<IEnumerable<Restaurant>> GetAllAsync();
        Task<IEnumerable<Restaurant>> GetApprovedOnlyAsync();
        Task<IEnumerable<Restaurant>> GetByOwnerIdAsync(string ownerId);
        Task<Restaurant?> GetByIdAsync(int id);
        Task AddAsync(Restaurant r);
        Task UpdateAsync(Restaurant r);
        Task DeleteAsync(int id);
    }
}
