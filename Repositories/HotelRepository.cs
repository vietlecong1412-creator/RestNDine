using DACS.Data;
using DACS.Models;
using Microsoft.EntityFrameworkCore;

namespace DACS.Repositories
{
    public class HotelRepository : IHotelRepository
    {
        private readonly ApplicationDbContext _context;

        public HotelRepository(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Hotel>> GetAllAsync()
        {
            return await _context.Hotels.ToListAsync();
        }

        public async Task<IEnumerable<Hotel>> GetApprovedOnlyAsync()
        {
            return await _context.Hotels.Where(h => h.IsApproved).ToListAsync();
        }

        public async Task<IEnumerable<Hotel>> GetByOwnerIdAsync(string ownerId)
        {
            return await _context.Hotels.Where(h => h.OwnerId == ownerId).ToListAsync();
        }

        public async Task<Hotel?> GetByIdAsync(int id)
        {
            return await _context.Hotels
                .Include(h => h.Comments)
                    .ThenInclude(c => c.User)
                .Include(h => h.Images)
                .FirstOrDefaultAsync(h => h.Id == id);
        }

        public async Task AddAsync(Hotel h)
        {
            await _context.Hotels.AddAsync(h);
            await _context.SaveChangesAsync();
        }

        public async Task UpdateAsync(Hotel h)
        {
            _context.Hotels.Update(h);
            await _context.SaveChangesAsync();
        }

        public async Task DeleteAsync(int id)
        {
            var h = await _context.Hotels.FindAsync(id);
            if (h != null)
            {
                _context.Hotels.Remove(h);
                await _context.SaveChangesAsync();
            }
        }
    }
}
