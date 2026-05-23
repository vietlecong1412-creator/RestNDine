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
            // 1. Tạo Roles nếu chưa có
            foreach (var role in new[] { "Admin", "Owner", "Customer" })
            {
                if (!await roleManager.RoleExistsAsync(role))
                    await roleManager.CreateAsync(new IdentityRole(role));
            }

            // 2. Tạo tài khoản mặc định
            await EnsureUser(userManager, "admin@gmail.com",    "Password@123", "Admin");
            await EnsureUser(userManager, "owner1@gmail.com",   "Password@123", "Owner");
            await EnsureUser(userManager, "customer1@gmail.com","Password@123", "Customer");
            await EnsureUser(userManager, "customer2@gmail.com","Password@123", "Customer");
            await EnsureUser(userManager, "customer3@gmail.com","Password@123", "Customer");

            // 3. Tự động gắn nhãn IsCafe cho các quán có tên chứa từ khóa cafe/coffee
            var untaggedCafes = await context.Restaurants
                .Where(r => !r.IsCafe && (
                    r.Name.ToLower().Contains("cà phê") ||
                    r.Name.ToLower().Contains("cafe")   ||
                    r.Name.ToLower().Contains("coffee") ||
                    r.Name.ToLower().Contains("café")
                ))
                .ToListAsync();

            if (untaggedCafes.Any())
            {
                foreach (var cafe in untaggedCafes)
                    cafe.IsCafe = true;
                await context.SaveChangesAsync();
            }
        }

        private static async Task EnsureUser(
            UserManager<IdentityUser> userManager,
            string email, string password, string role)
        {
            var user = await userManager.FindByEmailAsync(email);
            if (user != null) return;

            user = new IdentityUser { UserName = email, Email = email, EmailConfirmed = true };
            var result = await userManager.CreateAsync(user, password);
            if (result.Succeeded)
                await userManager.AddToRoleAsync(user, role);
        }
    }
}
