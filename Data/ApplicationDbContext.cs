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

        public DbSet<Restaurant> Restaurants { get; set; }
        public DbSet<Comment> Comments { get; set; }
        public DbSet<RestaurantImage> RestaurantImages { get; set; }
        public DbSet<Hotel> Hotels { get; set; }
        public DbSet<HotelComment> HotelComments { get; set; }
        public DbSet<HotelImage> HotelImages { get; set; }
    }
}
