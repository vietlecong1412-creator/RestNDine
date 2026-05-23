using DACS.Models;
using DACS.Repositories;
using DACS.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace DACS.Controllers
{
    public class HotelController : Controller
    {
        private readonly IHotelRepository _repo;
        private readonly UserManager<IdentityUser> _userManager;
        private readonly DACS.Data.ApplicationDbContext _context;
        private readonly IAiSummaryService _aiSummaryService;

        public HotelController(IHotelRepository repo, UserManager<IdentityUser> userManager, DACS.Data.ApplicationDbContext context, IAiSummaryService aiSummaryService)
        {
            _repo = repo;
            _userManager = userManager;
            _context = context;
            _aiSummaryService = aiSummaryService;
        }

        // GET: /Hotel/Details/5
        public async Task<IActionResult> Details(int id)
        {
            var hotel = await _repo.GetByIdAsync(id);
            if (hotel == null) return NotFound();

            var reviews = hotel.Comments?.Select(c => c.Content) ?? Enumerable.Empty<string>();
            ViewBag.AiSummary = await _aiSummaryService.SummarizeReviewsAsync(hotel.Name, reviews);

            return View(hotel);
        }

        // GET: /Hotel/Create
        [Authorize(Roles = "Owner,Admin")]
        public IActionResult Create()
        {
            return View();
        }

        // POST: /Hotel/Create
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Create(Hotel h, Microsoft.AspNetCore.Http.IFormFile? image)
        {
            if (ModelState.IsValid)
            {
                // Assign Owner
                h.OwnerId = _userManager.GetUserId(User);
                h.IsApproved = User.IsInRole("Admin"); // Auto-approve if Admin created it

                // Handle Image
                if (image != null && image.Length > 0)
                {
                    var fileExt = System.IO.Path.GetExtension(image.FileName);
                    var fileName = Guid.NewGuid().ToString() + fileExt;
                    var path = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "hotels", fileName);
                    
                    var dir = System.IO.Path.GetDirectoryName(path);
                    if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir!);

                    using (var stream = new System.IO.FileStream(path, System.IO.FileMode.Create))
                    {
                        await image.CopyToAsync(stream);
                    }
                    h.ImageUrl = $"/images/hotels/{fileName}";
                }

                await _repo.AddAsync(h);
                
                if (User.IsInRole("Admin")) 
                    return RedirectToAction("Index", "Hotel", new { area = "Admin" });
                
                TempData["Success"] = "Yêu cầu thêm khách sạn đã được gửi và đang chờ Admin duyệt.";
                return RedirectToAction("Index", "Home");
            }
            return View(h);
        }

        // GET: /Hotel/MyHotels
        [Authorize(Roles = "Owner")]
        public async Task<IActionResult> MyHotels()
        {
            var userId = _userManager.GetUserId(User);
            var myHotels = await _repo.GetByOwnerIdAsync(userId!);
            return View(myHotels);
        }

        // GET: /Hotel/Edit/5
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Edit(int id)
        {
            var h = await _repo.GetByIdAsync(id);
            if (h == null || (h.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }
            return View(h);
        }

        // POST: /Hotel/Edit/5
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Edit(int id, Hotel updated, Microsoft.AspNetCore.Http.IFormFile? image)
        {
            if (id != updated.Id) return BadRequest();

            var h = await _repo.GetByIdAsync(id);
            if (h == null || (h.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }

            if (ModelState.IsValid)
            {
                if (image != null && image.Length > 0)
                {
                    var fileExt = System.IO.Path.GetExtension(image.FileName);
                    var fileName = Guid.NewGuid().ToString() + fileExt;
                    var path = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "hotels", fileName);
                    var dir = System.IO.Path.GetDirectoryName(path);
                    if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir!);
                    using (var stream = new System.IO.FileStream(path, System.IO.FileMode.Create))
                    {
                        await image.CopyToAsync(stream);
                    }
                    h.ImageUrl = $"/images/hotels/{fileName}";
                }

                h.Name = updated.Name;
                h.Address = updated.Address;
                h.Description = updated.Description;
                h.Latitude = updated.Latitude;
                h.Longitude = updated.Longitude;
                h.PriceRange = updated.PriceRange;
                h.PhoneNumber = updated.PhoneNumber;
                h.StarRating = updated.StarRating;
                h.Amenities = updated.Amenities;

                await _repo.UpdateAsync(h);
                TempData["Success"] = "Cập nhật thông tin khách sạn và banner thành công!";
                
                if (User.IsInRole("Admin"))
                    return RedirectToAction("Index", "Hotel", new { area = "Admin" });
                
                return RedirectToAction(nameof(MyHotels));
            }
            return View(updated);
        }

        // GET: /Hotel/Delete/5
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var h = await _repo.GetByIdAsync(id);
            if (h == null || (h.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }
            return View(h);
        }

        // POST: /Hotel/Delete/5
        [HttpPost, ActionName("Delete")]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            var h = await _repo.GetByIdAsync(id);
            if (h == null || (h.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }
            await _repo.DeleteAsync(id);
            TempData["Success"] = "Đã xoá khách sạn thành công!";
            
            if (User.IsInRole("Admin"))
                return RedirectToAction("Index", "Hotel", new { area = "Admin" });
                
            return RedirectToAction(nameof(MyHotels));
        }

        // GET: /Hotel/Payment/5
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Payment(int id)
        {
            var h = await _repo.GetByIdAsync(id);
            if (h == null || (h.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }
            return View(h);
        }

        // POST: /Hotel/UpdateBanner
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> UpdateBanner(int id,
            Microsoft.AspNetCore.Http.IFormFile bannerImage,
            Microsoft.AspNetCore.Http.IFormFile paymentProof)
        {
            var h = await _repo.GetByIdAsync(id);
            if (h == null || (h.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
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
                h.BannerUrl = $"/images/banners/{fn}";
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
                    h.PaymentProofUrl = $"/images/payment/{fn}";
                }
                else
                {
                    TempData["Error"] = "Vui lòng upload ảnh biên lai chuyển khoản.";
                    hasError = true;
                }
            }

            if (!hasError)
            {
                h.BannerStatus = User.IsInRole("Admin") ? BannerStatus.Active : BannerStatus.PendingPayment;
                await _repo.UpdateAsync(h);
                TempData["Success"] = User.IsInRole("Admin")
                    ? "Banner đã được kích hoạt!"
                    : "Yêu cầu banner đã được gửi và đang chờ Admin xác nhận thanh toán.";
            }

            return RedirectToAction("Details", new { id = id });
        }

        // POST: /Hotel/DeleteBanner/5
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> DeleteBanner(int id)
        {
            var h = await _repo.GetByIdAsync(id);
            if (h == null || (h.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
            {
                return Unauthorized();
            }

            h.BannerUrl = null;
            h.PaymentProofUrl = null;
            h.BannerStatus = BannerStatus.None;
            await _repo.UpdateAsync(h);
            TempData["Success"] = "Đã xóa banner quảng cáo!";

            return RedirectToAction("Details", new { id = id });
        }

        // POST: /Hotel/AddComment
        [HttpPost]
        [Authorize]
        public async Task<IActionResult> AddComment(int hotelId, string content, int rating = 5)
        {
            if (string.IsNullOrWhiteSpace(content)) return BadRequest();
            if (rating < 1) rating = 1;
            if (rating > 5) rating = 5;

            var comment = new HotelComment
            {
                HotelId = hotelId,
                Content = content,
                Rating = rating,
                UserId = _userManager.GetUserId(User),
                CreatedAt = DateTime.Now
            };

            _context.HotelComments.Add(comment);
            await _context.SaveChangesAsync();

            return RedirectToAction("Details", new { id = hotelId });
        }

        // POST: /Hotel/AddImage
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> AddImage(int hotelId, Microsoft.AspNetCore.Http.IFormFile image)
        {
            var h = await _repo.GetByIdAsync(hotelId);
            if (h == null || (h.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            if (image == null || image.Length == 0)
            {
                TempData["Error"] = "Vui lòng chọn file ảnh hợp lệ.";
                return RedirectToAction("Details", new { id = hotelId });
            }

            var ext = System.IO.Path.GetExtension(image.FileName);
            var fn  = Guid.NewGuid().ToString() + ext;
            var dir = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "hotels");
            if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);
            var filePath = System.IO.Path.Combine(dir, fn);
            using (var stream = new System.IO.FileStream(filePath, System.IO.FileMode.Create))
            {
                await image.CopyToAsync(stream);
            }

            var img = new HotelImage
            {
                HotelId = hotelId,
                ImageUrl = $"/images/hotels/{fn}"
            };
            _context.HotelImages.Add(img);
            await _context.SaveChangesAsync();

            TempData["Success"] = "Đã thêm ảnh khách sạn thành công!";
            return RedirectToAction("Details", new { id = hotelId });
        }

        // POST: /Hotel/DeleteImage
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> DeleteImage(int imageId, int hotelId)
        {
            var img = await _context.HotelImages.FindAsync(imageId);
            if (img == null) return NotFound();

            var h = await _repo.GetByIdAsync(hotelId);
            if (h == null || (h.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            if (!string.IsNullOrEmpty(img.ImageUrl))
            {
                var physPath = System.IO.Path.Combine(
                    System.IO.Directory.GetCurrentDirectory(), "wwwroot",
                    img.ImageUrl.TrimStart('/').Replace('/', System.IO.Path.DirectorySeparatorChar));
                if (System.IO.File.Exists(physPath))
                    System.IO.File.Delete(physPath);
            }

            _context.HotelImages.Remove(img);
            await _context.SaveChangesAsync();

            TempData["Success"] = "Đã xóa ảnh!";
            return RedirectToAction("Details", new { id = hotelId });
        }
    }
}
