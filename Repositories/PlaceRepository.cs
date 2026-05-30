using DACS.Data;
using DACS.Models;
using Microsoft.EntityFrameworkCore;

namespace DACS.Repositories
{
    public class PlaceRepository : IPlaceRepository
    {
        private readonly ApplicationDbContext _context;

        public PlaceRepository(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Place>> GetAllAsync()
        {
            return await _context.Places
                .Include(p => p.Category)
                .ToListAsync();
        }

        public async Task<IEnumerable<Place>> GetApprovedOnlyAsync()
        {
            return await _context.Places
                .Include(p => p.Category)
                .Where(p => p.IsApproved)
                .ToListAsync();
        }

        public async Task<IEnumerable<Place>> GetByCategoryAsync(int categoryId)
        {
            return await _context.Places
                .Include(p => p.Category)
                .Where(p => p.CategoryId == categoryId && p.IsApproved)
                .ToListAsync();
        }

        public async Task<IEnumerable<Place>> GetByOwnerIdAsync(string ownerId)
        {
            return await _context.Places
                .Include(p => p.Category)
                .Where(p => p.OwnerId == ownerId)
                .ToListAsync();
        }

        public async Task<Place?> GetByIdAsync(int id)
        {
            return await _context.Places
                .Include(p => p.Category)
                .Include(p => p.Comments)
                    .ThenInclude(c => c.User)
                .Include(p => p.Images)
                .FirstOrDefaultAsync(p => p.Id == id);
        }

        public async Task AddAsync(Place place)
        {
            await _context.Places.AddAsync(place);
            await _context.SaveChangesAsync();
        }

        public async Task UpdateAsync(Place place)
        {
            _context.Places.Update(place);
            await _context.SaveChangesAsync();
        }

        public async Task DeleteAsync(int id)
        {
            var place = await _context.Places.FindAsync(id);
            if (place != null)
            {
                _context.Places.Remove(place);
                await _context.SaveChangesAsync();
            }
        }
    }
}
