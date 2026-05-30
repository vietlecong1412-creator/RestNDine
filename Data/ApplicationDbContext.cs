using DACS.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace DACS.Data
{
    public class ApplicationDbContext : IdentityDbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
         : base(options)
        {
        }

        // ── Bảng mới (Places) ──
        public DbSet<PlaceCategory> PlaceCategories { get; set; }
        public DbSet<Place> Places { get; set; }
        public DbSet<PlaceComment> PlaceComments { get; set; }
        public DbSet<PlaceImage> PlaceImages { get; set; }

    }
}
