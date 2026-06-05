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

        // ── Vote hữu ích ──
        public DbSet<CommentHelpfulVote> CommentHelpfulVotes { get; set; }

        // ── Chat thời gian thực ──
        public DbSet<ChatMessage> ChatMessages { get; set; }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);

            // Composite PK: (CommentId, UserId) → mỗi user chỉ vote 1 lần / bình luận
            builder.Entity<CommentHelpfulVote>()
                .HasKey(v => new { v.CommentId, v.UserId });

            // Index để query nhanh "user đã vote những bình luận nào"
            builder.Entity<CommentHelpfulVote>()
                .HasIndex(v => v.UserId);

            // Configure ChatMessage relationships with Restrict to avoid multiple cascading path conflicts
            builder.Entity<ChatMessage>()
                .HasOne(m => m.Sender)
                .WithMany()
                .HasForeignKey(m => m.SenderId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.Entity<ChatMessage>()
                .HasOne(m => m.Receiver)
                .WithMany()
                .HasForeignKey(m => m.ReceiverId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.Entity<ChatMessage>()
                .HasOne(m => m.Place)
                .WithMany()
                .HasForeignKey(m => m.PlaceId)
                .OnDelete(DeleteBehavior.Cascade);

            // Index for faster history query
            builder.Entity<ChatMessage>()
                .HasIndex(m => new { m.PlaceId, m.SenderId, m.ReceiverId });
        }
    }
}
