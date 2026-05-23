using DACS.Models;
using DACS.Repositories;
using DACS.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

namespace DACS.Controllers
{
    public class RestaurantController : Controller
    {
        private readonly IRestaurantRepository _repo;
        private readonly UserManager<IdentityUser> _userManager;
        private readonly DACS.Data.ApplicationDbContext _context;
        private readonly IAiSummaryService _aiSummaryService;

        public RestaurantController(IRestaurantRepository repo, UserManager<IdentityUser> userManager, DACS.Data.ApplicationDbContext context, IAiSummaryService aiSummaryService)
        {
            _repo = repo;
            _userManager = userManager;
            _context = context;
            _aiSummaryService = aiSummaryService;
        }

        // GET: /Restaurant/Details/5
        public async Task<IActionResult> Details(int id)
        {
            var restaurant = await _repo.GetByIdAsync(id);
            if (restaurant == null) return NotFound();

            var reviews = restaurant.Comments?.Select(c => c.Content) ?? Enumerable.Empty<string>();
            ViewBag.AiSummary = await _aiSummaryService.SummarizeReviewsAsync(restaurant.Name, reviews);

            return View(restaurant);
        }

        // GET: /Restaurant/Create
        [Authorize(Roles = "Owner,Admin")]
        public IActionResult Create()
        {
            return View();
        }

        // POST: /Restaurant/Create
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Create(Restaurant r, Microsoft.AspNetCore.Http.IFormFile? image)
        {
            if (ModelState.IsValid)
            {
                // Assign Owner
                r.OwnerId = _userManager.GetUserId(User);
                r.IsApproved = User.IsInRole("Admin"); // Auto-approve if Admin created it

                // Handle Image
                if (image != null && image.Length > 0)
                {
                    var fileExt = System.IO.Path.GetExtension(image.FileName);
                    var fileName = Guid.NewGuid().ToString() + fileExt;
                    var path = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "restaurants", fileName);
                    
                    var dir = System.IO.Path.GetDirectoryName(path);
                    if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir!);

                    using (var stream = new System.IO.FileStream(path, System.IO.FileMode.Create))
                    {
                        await image.CopyToAsync(stream);
                    }
                    r.ImageUrl = $"/images/restaurants/{fileName}";
                }

                await _repo.AddAsync(r);
                
                if (User.IsInRole("Admin")) 
                    return RedirectToAction("Index", "Restaurant", new { area = "Admin" });
                
                TempData["Success"] = "Yêu cầu thêm quán đã được gửi và đang chờ Admin duyệt.";
                return RedirectToAction("Index", "Home");
            }
            return View(r);
        }

        // GET: /Restaurant/MyRestaurants
        [Authorize(Roles = "Owner")]
        public async Task<IActionResult> MyRestaurants()
        {
            var userId = _userManager.GetUserId(User);
            var myRestaurants = await _repo.GetByOwnerIdAsync(userId!);
            return View(myRestaurants);
        }

        // GET: /Restaurant/Edit/5
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Edit(int id)
        {
            var r = await _repo.GetByIdAsync(id);
            if (r == null || (r.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }
            return View(r);
        }

        // POST: /Restaurant/Edit/5
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Edit(int id, Restaurant updated, Microsoft.AspNetCore.Http.IFormFile? image)
        {
            if (id != updated.Id) return BadRequest();

            var r = await _repo.GetByIdAsync(id);
            if (r == null || (r.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }

            if (ModelState.IsValid)
            {
                if (image != null && image.Length > 0)
                {
                    var fileExt = System.IO.Path.GetExtension(image.FileName);
                    var fileName = Guid.NewGuid().ToString() + fileExt;
                    var path = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "restaurants", fileName);
                    var dir = System.IO.Path.GetDirectoryName(path);
                    if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir!);
                    using (var stream = new System.IO.FileStream(path, System.IO.FileMode.Create))
                    {
                        await image.CopyToAsync(stream);
                    }
                    r.ImageUrl = $"/images/restaurants/{fileName}";
                }

                r.Name = updated.Name;
                r.Address = updated.Address;
                r.Description = updated.Description;
                r.Latitude = updated.Latitude;
                r.Longitude = updated.Longitude;
                r.PriceRange = updated.PriceRange;
                r.PhoneNumber = updated.PhoneNumber;
                r.IsCafe = updated.IsCafe;

                await _repo.UpdateAsync(r);
                TempData["Success"] = "Cập nhật thông tin và banner thành công!";
                
                if (User.IsInRole("Admin"))
                    return RedirectToAction("Index", "Restaurant", new { area = "Admin" });
                
                return RedirectToAction(nameof(MyRestaurants));
            }
            return View(updated);
        }

        // GET: /Restaurant/Delete/5
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var r = await _repo.GetByIdAsync(id);
            if (r == null || (r.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }
            return View(r);
        }

        // POST: /Restaurant/Delete/5
        [HttpPost, ActionName("Delete")]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            var r = await _repo.GetByIdAsync(id);
            if (r == null || (r.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }
            await _repo.DeleteAsync(id);
            TempData["Success"] = "Đã xoá quán ăn thành công!";
            
            if (User.IsInRole("Admin"))
                return RedirectToAction("Index", "Restaurant", new { area = "Admin" });
                
            return RedirectToAction(nameof(MyRestaurants));
        }

        // GET: /Restaurant/Payment/5
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Payment(int id)
        {
            var r = await _repo.GetByIdAsync(id);
            if (r == null || (r.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }
            return View(r);
        }

        // POST: /Restaurant/UpdateBanner
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> UpdateBanner(int id,
            Microsoft.AspNetCore.Http.IFormFile bannerImage,
            Microsoft.AspNetCore.Http.IFormFile paymentProof)
        {
            var r = await _repo.GetByIdAsync(id);
            if (r == null || (r.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            bool hasError = false;

            // Save banner image
            if (bannerImage != null && bannerImage.Length > 0)
            {
                var ext = System.IO.Path.GetExtension(bannerImage.FileName);
                var fn  = Guid.NewGuid().ToString() + ext;
                var dir = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "banners");
                if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);
                using var s = new System.IO.FileStream(System.IO.Path.Combine(dir, fn), System.IO.FileMode.Create);
                await bannerImage.CopyToAsync(s);
                r.BannerUrl = $"/images/banners/{fn}";
            }
            else
            {
                TempData["Error"] = "Vui lòng chọn ảnh banner hợp lệ.";
                hasError = true;
            }

            // Save payment proof
            if (!hasError)
            {
                if (paymentProof != null && paymentProof.Length > 0)
                {
                    var ext = System.IO.Path.GetExtension(paymentProof.FileName);
                    var fn  = Guid.NewGuid().ToString() + ext;
                    var dir = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "payment");
                    if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);
                    using var s = new System.IO.FileStream(System.IO.Path.Combine(dir, fn), System.IO.FileMode.Create);
                    await paymentProof.CopyToAsync(s);
                    r.PaymentProofUrl = $"/images/payment/{fn}";
                }
                else
                {
                    TempData["Error"] = "Vui lòng upload ảnh biên lai chuyển khoản.";
                    hasError = true;
                }
            }

            if (!hasError)
            {
                // Admin can approve immediately; owners go through review
                r.BannerStatus = User.IsInRole("Admin") ? BannerStatus.Active : BannerStatus.PendingPayment;
                await _repo.UpdateAsync(r);
                TempData["Success"] = User.IsInRole("Admin")
                    ? "Banner đã được kích hoạt!"
                    : "Yêu cầu banner đã được gửi và đang chờ Admin xác nhận thanh toán.";
            }

            return RedirectToAction("Details", new { id = id });
        }


        // POST: /Restaurant/DeleteBanner/5
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> DeleteBanner(int id)
        {
            var r = await _repo.GetByIdAsync(id);
            if (r == null || (r.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }

            // Reset banner data (files left on disk intentionally)
            r.BannerUrl = null;
            r.PaymentProofUrl = null;
            r.BannerStatus = BannerStatus.None;
            await _repo.UpdateAsync(r);
            TempData["Success"] = "Đã xóa banner quảng cáo!";

            return RedirectToAction("Details", new { id = id });
        }


        // POST: /Restaurant/AddComment
        [HttpPost]
        [Authorize]
        public async Task<IActionResult> AddComment(int restaurantId, string content, int rating = 5)
        {
            if (string.IsNullOrWhiteSpace(content)) return BadRequest();
            if (rating < 1) rating = 1;
            if (rating > 5) rating = 5;

            var comment = new Comment
            {
                RestaurantId = restaurantId,
                Content = content,
                Rating = rating,
                UserId = _userManager.GetUserId(User),
                CreatedAt = DateTime.Now
            };

            _context.Comments.Add(comment);
            await _context.SaveChangesAsync();

            return RedirectToAction("Details", new { id = restaurantId });
        }
        // POST: /Restaurant/AddImage
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> AddImage(int restaurantId, Microsoft.AspNetCore.Http.IFormFile image)
        {
            var r = await _repo.GetByIdAsync(restaurantId);
            if (r == null || (r.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            if (image == null || image.Length == 0)
            {
                TempData["Error"] = "Vui lòng chọn file ảnh hợp lệ.";
                return RedirectToAction("Details", new { id = restaurantId });
            }

            var ext = System.IO.Path.GetExtension(image.FileName);
            var fn  = Guid.NewGuid().ToString() + ext;
            var dir = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "restaurants");
            if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);
            var filePath = System.IO.Path.Combine(dir, fn);
            using (var stream = new System.IO.FileStream(filePath, System.IO.FileMode.Create))
            {
                await image.CopyToAsync(stream);
            }

            var img = new DACS.Models.RestaurantImage
            {
                RestaurantId = restaurantId,
                ImageUrl = $"/images/restaurants/{fn}"
            };
            _context.RestaurantImages.Add(img);
            await _context.SaveChangesAsync();

            TempData["Success"] = "Đã thêm ảnh thành công!";
            return RedirectToAction("Details", new { id = restaurantId });
        }

        // POST: /Restaurant/DeleteImage
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> DeleteImage(int imageId, int restaurantId)
        {
            var img = await _context.RestaurantImages.FindAsync(imageId);
            if (img == null) return NotFound();

            // Check ownership
            var r = await _repo.GetByIdAsync(restaurantId);
            if (r == null || (r.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            // Delete physical file
            if (!string.IsNullOrEmpty(img.ImageUrl))
            {
                var physPath = System.IO.Path.Combine(
                    System.IO.Directory.GetCurrentDirectory(), "wwwroot",
                    img.ImageUrl.TrimStart('/').Replace('/', System.IO.Path.DirectorySeparatorChar));
                if (System.IO.File.Exists(physPath))
                    System.IO.File.Delete(physPath);
            }

            _context.RestaurantImages.Remove(img);
            await _context.SaveChangesAsync();

            TempData["Success"] = "Đã xóa ảnh!";
            return RedirectToAction("Details", new { id = restaurantId });
        }
    }
}
