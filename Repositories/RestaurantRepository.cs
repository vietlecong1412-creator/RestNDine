using DACS.Data;
using DACS.Models;
using Microsoft.EntityFrameworkCore;

namespace DACS.Repositories
{
    public class RestaurantRepository : IRestaurantRepository
    {
        private readonly ApplicationDbContext _context;

        public RestaurantRepository(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Restaurant>> GetAllAsync()
        {
            return await _context.Restaurants.ToListAsync();
        }

        public async Task<IEnumerable<Restaurant>> GetApprovedOnlyAsync()
        {
            return await _context.Restaurants.Where(r => r.IsApproved).ToListAsync();
        }

        public async Task<IEnumerable<Restaurant>> GetByOwnerIdAsync(string ownerId)
        {
            return await _context.Restaurants.Where(r => r.OwnerId == ownerId).ToListAsync();
        }

        public async Task<Restaurant?> GetByIdAsync(int id)
        {
            return await _context.Restaurants
                .Include(r => r.Comments)
                    .ThenInclude(c => c.User)
                .Include(r => r.Images)
                .FirstOrDefaultAsync(r => r.Id == id);
        }

        public async Task AddAsync(Restaurant r)
        {
            await _context.Restaurants.AddAsync(r);
            await _context.SaveChangesAsync();
        }

        public async Task UpdateAsync(Restaurant r)
        {
            _context.Restaurants.Update(r);
            await _context.SaveChangesAsync();
        }

        public async Task DeleteAsync(int id)
        {
            var r = await _context.Restaurants.FindAsync(id);
            if (r != null)
            {
                _context.Restaurants.Remove(r);
                await _context.SaveChangesAsync();
            }
        }
    }
}
