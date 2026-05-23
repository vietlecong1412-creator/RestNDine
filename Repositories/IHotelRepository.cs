using DACS.Models;

namespace DACS.Repositories
{
    public interface IHotelRepository
    {
        Task<IEnumerable<Hotel>> GetAllAsync();
        Task<IEnumerable<Hotel>> GetApprovedOnlyAsync();
        Task<IEnumerable<Hotel>> GetByOwnerIdAsync(string ownerId);
        Task<Hotel?> GetByIdAsync(int id);
        Task AddAsync(Hotel h);
        Task UpdateAsync(Hotel h);
        Task DeleteAsync(int id);
    }
}
