using DACS.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace DACS.Data
{
    public static class DbInitializer
    {
        public static async Task SeedDataAsync(
            UserManager<IdentityUser> userManager,
            RoleManager<IdentityRole> roleManager,
            ApplicationDbContext context)
        {
            // Tự động áp dụng Migration khi khởi chạy
            await context.Database.MigrateAsync();

            // 1. Tạo Roles
            foreach (var role in new[] { "Admin", "Owner", "Customer" })
            {
                if (!await roleManager.RoleExistsAsync(role))
                    await roleManager.CreateAsync(new IdentityRole(role));
            }

            // 2. Tạo tài khoản mặc định
            await EnsureUser(userManager, "admin@gmail.com",     "Password@123", "Admin");
            await EnsureUser(userManager, "owner1@gmail.com",    "Password@123", "Owner");
            await EnsureUser(userManager, "customer1@gmail.com", "Password@123", "Customer");
            await EnsureUser(userManager, "customer2@gmail.com", "Password@123", "Customer");
            await EnsureUser(userManager, "customer3@gmail.com", "Password@123", "Customer");

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
            if (result.Succeeded)
                await userManager.AddToRoleAsync(user, role);
        }
    }
}
