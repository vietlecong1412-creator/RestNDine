using DACS.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace DACS.Data
{
    public static class DbInitializer
    {
        // Mật khẩu mẫu nằm ngay trong source code, chỉ được dùng khi phát triển
        private const string SamplePassword = "Password@123";

        private static readonly (string Email, string Role)[] SampleUsers =
        {
            ("admin@gmail.com",     "Admin"),
            ("owner1@gmail.com",    "Owner"),
            ("customer1@gmail.com", "Customer"),
            ("customer2@gmail.com", "Customer"),
            ("customer3@gmail.com", "Customer"),
        };

        public static async Task SeedDataAsync(
            UserManager<IdentityUser> userManager,
            RoleManager<IdentityRole> roleManager,
            ApplicationDbContext context,
            IHostEnvironment environment,
            IConfiguration configuration,
            ILogger logger)
        {
            // Tự động áp dụng Migration khi khởi chạy
            await context.Database.MigrateAsync();

            // 1. Tạo Roles
            foreach (var role in new[] { "Admin", "Owner", "Customer" })
            {
                if (!await roleManager.RoleExistsAsync(role))
                    await roleManager.CreateAsync(new IdentityRole(role));
            }

            // 2. Tạo tài khoản
            if (environment.IsDevelopment())
            {
                foreach (var (email, role) in SampleUsers)
                    await EnsureUser(userManager, email, SamplePassword, role);
            }
            else
            {
                await EnsureProductionAdminAsync(userManager, configuration, logger);
                await ThrowIfSampleCredentialsRemainAsync(userManager);
            }

            // 3. Seed PlaceCategories nếu chưa có
            if (!await context.PlaceCategories.AnyAsync())
            {
                context.PlaceCategories.AddRange(
                    new PlaceCategory { Id = 1, Name = "Nhà hàng",    Slug = "restaurant", Icon = "🍴" },
                    new PlaceCategory { Id = 2, Name = "Khách sạn",   Slug = "hotel",      Icon = "🏨" },
                    new PlaceCategory { Id = 3, Name = "Quán cà phê", Slug = "cafe",       Icon = "☕" }
                );
                await context.SaveChangesAsync();
            }

            // 4. Khôi phục categories cho places cũ + thêm test places nhiều categories
            await SeedCategoriesForExistingPlacesAsync(context, environment.IsDevelopment());

        }

        /// <summary>Admin production lấy từ cấu hình; không ghi đè mật khẩu nếu tài khoản đã có.</summary>
        private static async Task EnsureProductionAdminAsync(
            UserManager<IdentityUser> userManager,
            IConfiguration configuration,
            ILogger logger)
        {
            var email = configuration["SeedAdmin:Email"];
            var password = configuration["SeedAdmin:Password"];

            if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
            {
                logger.LogWarning("Chưa cấu hình SeedAdmin__Email và SeedAdmin__Password nên không tạo tài khoản Admin.");
                return;
            }

            if (password == SamplePassword)
                throw new InvalidOperationException("SeedAdmin:Password không được dùng mật khẩu mẫu.");

            await EnsureUser(userManager, email, password, "Admin");
        }

        /// <summary>
        /// Không cho chạy production khi còn tài khoản mẫu dùng mật khẩu có trong source code,
        /// vì ai đọc được code cũng đăng nhập được (kể cả quyền Admin).
        /// </summary>
        private static async Task ThrowIfSampleCredentialsRemainAsync(UserManager<IdentityUser> userManager)
        {
            var exposed = new List<string>();
            foreach (var (email, _) in SampleUsers)
            {
                var user = await userManager.FindByEmailAsync(email);
                if (user != null && await userManager.CheckPasswordAsync(user, SamplePassword))
                    exposed.Add(email);
            }

            if (exposed.Count > 0)
                throw new InvalidOperationException(
                    $"Không thể chạy production: các tài khoản sau vẫn dùng mật khẩu mẫu: {string.Join(", ", exposed)}. " +
                    "Hãy đổi mật khẩu, xoá các tài khoản này, hoặc dùng database riêng cho production.");
        }

        // Gán lại categories cho places dựa theo tên, và thêm test places multi-category (chỉ khi phát triển)
        private static async Task SeedCategoriesForExistingPlacesAsync(ApplicationDbContext context, bool addTestPlaces)
        {
            var catRestaurant = await context.PlaceCategories.FirstOrDefaultAsync(c => c.Slug == "restaurant");
            var catHotel      = await context.PlaceCategories.FirstOrDefaultAsync(c => c.Slug == "hotel");
            var catCafe       = await context.PlaceCategories.FirstOrDefaultAsync(c => c.Slug == "cafe");
            if (catRestaurant == null || catHotel == null || catCafe == null) return;

            // Lấy tất cả places chưa có category
            var placesWithNoCategories = await context.Places
                .Include(p => p.Categories)
                .Where(p => !p.Categories.Any())
                .ToListAsync();

            if (!placesWithNoCategories.Any()) return;

            var hotelKeywords = new[] { "khách sạn", "hotel", "resort", "boutique hotel", "inn" };
            var cafeKeywords  = new[] { "cà phê", "coffee", "cafe", "trà sữa", "tea", "koi thé", "gong cha", "katinat", "highlands", "phúc long", "the coffee house", "trung nguyên", "cộng cà phê" };

            foreach (var place in placesWithNoCategories)
            {
                var nameLower = place.Name.ToLower();

                bool isHotel = hotelKeywords.Any(k => nameLower.Contains(k));
                bool isCafe  = cafeKeywords.Any(k => nameLower.Contains(k));

                if (isHotel)
                    place.Categories.Add(catHotel);
                else if (isCafe)
                    place.Categories.Add(catCafe);
                else
                    place.Categories.Add(catRestaurant);
            }

            await context.SaveChangesAsync();

            if (!addTestPlaces) return;

            // Thêm test places nhiều categories (chỉ nếu chưa tồn tại)
            var testPlaces = new[]
            {
                new {
                    Name = "TEST - Khách sạn + Nhà hàng (InterContinental Demo)",
                    Address = "39 Lê Duẩn, Quận 1, TP.HCM",
                    Desc = "Test: Khách sạn 5 sao có nhà hàng buffet và bar tầng thượng.",
                    Lat = 10.7795, Lng = 106.7006, Price = "3.000.000 - 8.000.000",
                    Star = (int?)5, Amenities = "Hồ bơi, Spa, Nhà hàng Buffet, Rooftop Bar",
                    Cats = new[] { catHotel, catRestaurant }
                },
                new {
                    Name = "TEST - Khách sạn + Nhà hàng + Cafe (Pullman Demo)",
                    Address = "40 Cát Linh, Đống Đa, Hà Nội",
                    Desc = "Test: Khách sạn hạng sang với nhà hàng và cafe lounge.",
                    Lat = 21.0278, Lng = 105.8342, Price = "2.000.000 - 6.000.000",
                    Star = (int?)5, Amenities = "Hồ bơi, Gym, Cafe Lounge, Nhà hàng Quốc tế",
                    Cats = new[] { catHotel, catRestaurant, catCafe }
                },
                new {
                    Name = "TEST - Nhà hàng + Quán cafe (Cộng Demo)",
                    Address = "25 Đinh Lễ, Hoàn Kiếm, Hà Nội",
                    Desc = "Test: Quán phong cách Đông Dương, vừa cafe vừa ăn vặt.",
                    Lat = 21.0290, Lng = 105.8520, Price = "30k - 70k",
                    Star = (int?)null, Amenities = (string?)null,
                    Cats = new[] { catCafe, catRestaurant }
                },
            };

            foreach (var t in testPlaces)
            {
                if (!await context.Places.AnyAsync(p => p.Name == t.Name))
                {
                    var p = new Place
                    {
                        Name = t.Name, Address = t.Address, Description = t.Desc,
                        Latitude = t.Lat, Longitude = t.Lng, PriceRange = t.Price,
                        IsApproved = true, StarRating = t.Star, Amenities = t.Amenities
                    };
                    foreach (var c in t.Cats) p.Categories.Add(c);
                    context.Places.Add(p);
                }
            }

            await context.SaveChangesAsync();
        }

        private static async Task EnsureUser(
            UserManager<IdentityUser> userManager,
            string email, string password, string role)
        {
            var user = await userManager.FindByEmailAsync(email);
            if (user != null)
            {
                if (!user.EmailConfirmed)
                {
                    user.EmailConfirmed = true;
                    await userManager.UpdateAsync(user);
                }
                if (!await userManager.IsInRoleAsync(user, role))
                    await userManager.AddToRoleAsync(user, role);
                return;
            }

            user = new IdentityUser { UserName = email, Email = email, EmailConfirmed = true };
            var result = await userManager.CreateAsync(user, password);
            if (!result.Succeeded)
                throw new InvalidOperationException(
                    $"Không tạo được tài khoản {email}: {string.Join("; ", result.Errors.Select(e => e.Description))}");

            await userManager.AddToRoleAsync(user, role);
        }
    }
}
