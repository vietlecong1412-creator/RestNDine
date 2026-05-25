using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using DACS.Areas.Admin.Models;
using DACS.Data;

namespace DACS.Areas.Admin.Controllers
{
    [Area("Admin")]
    [Authorize(Roles = "Admin")]
    public class UserController : Controller
    {
        private readonly UserManager<IdentityUser> _userManager;
        private readonly RoleManager<IdentityRole> _roleManager;
        private readonly ApplicationDbContext _context;

        public UserController(
            UserManager<IdentityUser> userManager, 
            RoleManager<IdentityRole> roleManager,
            ApplicationDbContext context)
        {
            _userManager = userManager;
            _roleManager = roleManager;
            _context = context;
        }

        public async Task<IActionResult> Index(string searchTerm = null, string roleFilter = null)
        {
            var users = _userManager.Users.ToList();
            var list = new List<UserListViewModel>();

            foreach (var user in users)
            {
                var roles = await _userManager.GetRolesAsync(user);
                var role = roles.FirstOrDefault() ?? "Customer";

                // Filter search
                if (!string.IsNullOrEmpty(searchTerm) && !user.Email.Contains(searchTerm, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                // Filter role
                if (!string.IsNullOrEmpty(roleFilter) && !role.Equals(roleFilter, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                var isLocked = await _userManager.IsLockedOutAsync(user);

                list.Add(new UserListViewModel
                {
                    Id = user.Id,
                    Email = user.Email,
                    Role = role,
                    IsLockedOut = isLocked,
                    LockoutEnd = user.LockoutEnd
                });
            }

            ViewBag.SearchTerm = searchTerm;
            ViewBag.RoleFilter = roleFilter;

            return View(list.OrderBy(u => u.Email).ToList());
        }

        [HttpPost]
        public async Task<IActionResult> ChangeRole(string userId, string newRole)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound();

            // Ngăn Admin tự tước quyền Admin của chính mình
            var currentUser = await _userManager.GetUserAsync(User);
            if (currentUser != null && currentUser.Id == userId && newRole != "Admin")
            {
                TempData["Error"] = "Bạn không thể tự tước quyền Admin của chính mình!";
                return RedirectToAction(nameof(Index));
            }

            var currentRoles = await _userManager.GetRolesAsync(user);
            await _userManager.RemoveFromRolesAsync(user, currentRoles);
            
            if (newRole == "Admin" || newRole == "Owner" || newRole == "Customer")
            {
                await _userManager.AddToRoleAsync(user, newRole);
                TempData["Success"] = $"Đã cập nhật quyền thành công cho {user.Email} thành {newRole}!";
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        public async Task<IActionResult> ToggleLockout(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound();

            // Ngăn Admin tự khóa tài khoản của chính mình
            var currentUser = await _userManager.GetUserAsync(User);
            if (currentUser != null && currentUser.Id == userId)
            {
                TempData["Error"] = "Bạn không thể tự khóa tài khoản của chính mình!";
                return RedirectToAction(nameof(Index));
            }

            var isLocked = await _userManager.IsLockedOutAsync(user);
            if (isLocked)
            {
                // Mở khóa
                await _userManager.SetLockoutEndDateAsync(user, null);
                TempData["Success"] = $"Đã mở khóa tài khoản cho {user.Email}!";
            }
            else
            {
                // Khóa tài khoản
                await _userManager.SetLockoutEndDateAsync(user, DateTimeOffset.UtcNow.AddYears(100));
                TempData["Success"] = $"Đã khóa tài khoản thành công cho {user.Email}!";
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        public async Task<IActionResult> DeleteUser(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound();

            // Ngăn Admin tự xóa tài khoản của chính mình
            var currentUser = await _userManager.GetUserAsync(User);
            if (currentUser != null && currentUser.Id == userId)
            {
                TempData["Error"] = "Bạn không thể tự xóa tài khoản của chính mình!";
                return RedirectToAction(nameof(Index));
            }

            try
            {
                // 1. Xóa toàn bộ NHÀ HÀNG sở hữu bởi người dùng này
                // (Các hình ảnh RestaurantImages và bình luận Comments thuộc nhà hàng sẽ tự động xóa Cascade nhờ ràng buộc khóa ngoại ở DB)
                var ownedRestaurants = _context.Restaurants.Where(r => r.OwnerId == userId);
                _context.Restaurants.RemoveRange(ownedRestaurants);

                // 2. Xóa toàn bộ KHÁCH SẠN sở hữu bởi người dùng này
                // (Các hình ảnh HotelImages và bình luận HotelComments thuộc khách sạn sẽ tự động xóa Cascade nhờ ràng buộc khóa ngoại ở DB)
                var ownedHotels = _context.Hotels.Where(h => h.OwnerId == userId);
                _context.Hotels.RemoveRange(ownedHotels);

                // Áp dụng các thay đổi xóa nhà hàng/khách sạn sở hữu trước
                await _context.SaveChangesAsync();

                // 3. Tiến hành xóa tài khoản người dùng
                // (Toàn bộ bình luận do người dùng này viết tại các địa điểm khác cũng tự động được DB xóa Cascade nhờ ràng buộc khóa ngoại UserId)
                var result = await _userManager.DeleteAsync(user);
                if (result.Succeeded)
                {
                    TempData["Success"] = $"Đã xóa tài khoản {user.Email} khỏi hệ thống thành công!";
                }
                else
                {
                    TempData["Error"] = "Đã xảy ra lỗi khi xóa tài khoản từ hệ thống Identity.";
                }
            }
            catch (Exception ex)
            {
                TempData["Error"] = $"Lỗi hệ thống cơ sở dữ liệu: {ex.Message}";
            }

            return RedirectToAction(nameof(Index));
        }
    }
}
