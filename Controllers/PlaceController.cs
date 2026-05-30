using DACS.Models;
using DACS.Repositories;
using DACS.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;

namespace DACS.Controllers
{
    public class PlaceController : Controller
    {
        private readonly IPlaceRepository _repo;
        private readonly UserManager<IdentityUser> _userManager;
        private readonly DACS.Data.ApplicationDbContext _context;
        private readonly IAiSummaryService _aiSummaryService;

        public PlaceController(
            IPlaceRepository repo,
            UserManager<IdentityUser> userManager,
            DACS.Data.ApplicationDbContext context,
            IAiSummaryService aiSummaryService)
        {
            _repo = repo;
            _userManager = userManager;
            _context = context;
            _aiSummaryService = aiSummaryService;
        }

        // ─────────────────────────────────────
        // GET: /Place/Details/5
        // ─────────────────────────────────────
        public async Task<IActionResult> Details(int id)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place == null) return NotFound();

            // ── AI Summary Cache Logic ──
            bool cacheValid = !string.IsNullOrEmpty(place.AiSummaryCache)
                && place.AiSummaryCacheUpdatedAt.HasValue
                && (!place.Comments.Any()
                    || place.Comments.Max(c => c.CreatedAt) <= place.AiSummaryCacheUpdatedAt.Value);

            if (cacheValid)
            {
                ViewBag.AiSummary = place.AiSummaryCache;
            }
            else
            {
                var reviews = place.Comments?.Select(c => c.Content) ?? Enumerable.Empty<string>();
                var summary = await _aiSummaryService.SummarizeReviewsAsync(place.Name, reviews);
                ViewBag.AiSummary = summary;

                place.AiSummaryCache = summary;
                place.AiSummaryCacheUpdatedAt = DateTime.Now;
                await _repo.UpdateAsync(place);
            }

            // ── Truyền danh sách commentId mà user hiện tại đã vote xuống View ──
            var currentUserId = _userManager.GetUserId(User);
            if (currentUserId != null)
            {
                var commentIds = place.Comments.Select(c => c.Id).ToList();
                var votedIds = await _context.CommentHelpfulVotes
                    .Where(v => v.UserId == currentUserId && commentIds.Contains(v.CommentId))
                    .Select(v => v.CommentId)
                    .ToListAsync();
                ViewBag.VotedCommentIds = new HashSet<int>(votedIds);
            }
            else
            {
                ViewBag.VotedCommentIds = new HashSet<int>();
            }

            return View(place);
        }


        // ─────────────────────────────────────
        // GET: /Place/Create
        // ─────────────────────────────────────
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Create()
        {
            ViewBag.Categories = new SelectList(
                await _context.PlaceCategories.ToListAsync(), "Id", "Name");
            return View();
        }

        // POST: /Place/Create
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Create(Place place, Microsoft.AspNetCore.Http.IFormFile? image)
        {
            if (ModelState.IsValid)
            {
                place.OwnerId = _userManager.GetUserId(User);
                place.IsApproved = User.IsInRole("Admin");

                if (image != null && image.Length > 0)
                {
                    var fileExt = System.IO.Path.GetExtension(image.FileName);
                    var fileName = Guid.NewGuid().ToString() + fileExt;
                    var dir = System.IO.Path.Combine(
                        System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "places");
                    if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);
                    var path = System.IO.Path.Combine(dir, fileName);
                    using (var stream = new System.IO.FileStream(path, System.IO.FileMode.Create))
                        await image.CopyToAsync(stream);
                    place.ImageUrl = $"/images/places/{fileName}";
                }

                await _repo.AddAsync(place);

                if (User.IsInRole("Admin"))
                    return RedirectToAction("Index", "Place", new { area = "Admin" });

                TempData["Success"] = "Yêu cầu thêm địa điểm đã được gửi và đang chờ Admin duyệt.";
                return RedirectToAction("Index", "Home");
            }

            ViewBag.Categories = new SelectList(
                await _context.PlaceCategories.ToListAsync(), "Id", "Name", place.CategoryId);
            return View(place);
        }

        // ─────────────────────────────────────
        // GET: /Place/MyPlaces
        // ─────────────────────────────────────
        [Authorize(Roles = "Owner")]
        public async Task<IActionResult> MyPlaces()
        {
            var userId = _userManager.GetUserId(User);
            var myPlaces = await _repo.GetByOwnerIdAsync(userId!);
            return View(myPlaces);
        }

        // ─────────────────────────────────────
        // GET: /Place/Edit/5
        // ─────────────────────────────────────
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Edit(int id)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            ViewBag.Categories = new SelectList(
                await _context.PlaceCategories.ToListAsync(), "Id", "Name", place.CategoryId);
            return View(place);
        }

        // POST: /Place/Edit/5
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Edit(int id, Place updated, Microsoft.AspNetCore.Http.IFormFile? image)
        {
            if (id != updated.Id) return BadRequest();

            var place = await _repo.GetByIdAsync(id);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            if (ModelState.IsValid)
            {
                if (image != null && image.Length > 0)
                {
                    var fileExt = System.IO.Path.GetExtension(image.FileName);
                    var fileName = Guid.NewGuid().ToString() + fileExt;
                    var dir = System.IO.Path.Combine(
                        System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "places");
                    if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);
                    var path = System.IO.Path.Combine(dir, fileName);
                    using (var stream = new System.IO.FileStream(path, System.IO.FileMode.Create))
                        await image.CopyToAsync(stream);
                    place.ImageUrl = $"/images/places/{fileName}";
                }

                place.Name        = updated.Name;
                place.Address     = updated.Address;
                place.Description = updated.Description;
                place.Latitude    = updated.Latitude;
                place.Longitude   = updated.Longitude;
                place.PriceRange  = updated.PriceRange;
                place.PhoneNumber = updated.PhoneNumber;
                place.CategoryId  = updated.CategoryId;
                place.StarRating  = updated.StarRating;
                place.Amenities   = updated.Amenities;

                await _repo.UpdateAsync(place);
                TempData["Success"] = "Cập nhật thông tin địa điểm thành công!";

                if (User.IsInRole("Admin"))
                    return RedirectToAction("Index", "Place", new { area = "Admin" });

                return RedirectToAction(nameof(MyPlaces));
            }

            ViewBag.Categories = new SelectList(
                await _context.PlaceCategories.ToListAsync(), "Id", "Name", updated.CategoryId);
            return View(updated);
        }

        // ─────────────────────────────────────
        // GET/POST: /Place/Delete/5
        // ─────────────────────────────────────
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();
            return View(place);
        }

        [HttpPost, ActionName("Delete")]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            await _repo.DeleteAsync(id);
            TempData["Success"] = "Đã xoá địa điểm thành công!";

            if (User.IsInRole("Admin"))
                return RedirectToAction("Index", "Place", new { area = "Admin" });

            return RedirectToAction(nameof(MyPlaces));
        }

        // ─────────────────────────────────────
        // Payment / Banner
        // ─────────────────────────────────────
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Payment(int id)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();
            return View(place);
        }

        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> UpdateBanner(int id,
            Microsoft.AspNetCore.Http.IFormFile bannerImage,
            Microsoft.AspNetCore.Http.IFormFile paymentProof)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            bool hasError = false;

            if (bannerImage != null && bannerImage.Length > 0)
            {
                var ext = System.IO.Path.GetExtension(bannerImage.FileName);
                var fn  = Guid.NewGuid().ToString() + ext;
                var dir = System.IO.Path.Combine(
                    System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "banners");
                if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);
                using var s = new System.IO.FileStream(
                    System.IO.Path.Combine(dir, fn), System.IO.FileMode.Create);
                await bannerImage.CopyToAsync(s);
                place.BannerUrl = $"/images/banners/{fn}";
            }
            else
            {
                TempData["Error"] = "Vui lòng chọn ảnh banner hợp lệ.";
                hasError = true;
            }

            if (!hasError)
            {
                if (paymentProof != null && paymentProof.Length > 0)
                {
                    var ext = System.IO.Path.GetExtension(paymentProof.FileName);
                    var fn  = Guid.NewGuid().ToString() + ext;
                    var dir = System.IO.Path.Combine(
                        System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "payment");
                    if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);
                    using var s = new System.IO.FileStream(
                        System.IO.Path.Combine(dir, fn), System.IO.FileMode.Create);
                    await paymentProof.CopyToAsync(s);
                    place.PaymentProofUrl = $"/images/payment/{fn}";
                }
                else
                {
                    TempData["Error"] = "Vui lòng upload ảnh biên lai chuyển khoản.";
                    hasError = true;
                }
            }

            if (!hasError)
            {
                place.BannerStatus = User.IsInRole("Admin") ? BannerStatus.Active : BannerStatus.PendingPayment;
                await _repo.UpdateAsync(place);
                TempData["Success"] = User.IsInRole("Admin")
                    ? "Banner đã được kích hoạt!"
                    : "Yêu cầu banner đã được gửi và đang chờ Admin xác nhận thanh toán.";
            }

            return RedirectToAction("Details", new { id });
        }

        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> DeleteBanner(int id)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            place.BannerUrl       = null;
            place.PaymentProofUrl = null;
            place.BannerStatus    = BannerStatus.None;
            await _repo.UpdateAsync(place);
            TempData["Success"] = "Đã xóa banner quảng cáo!";

            return RedirectToAction("Details", new { id });
        }

        // ─────────────────────────────────────
        // Comments
        // ─────────────────────────────────────
        [HttpPost]
        [Authorize]
        public async Task<IActionResult> AddComment(int placeId, string content, int rating = 5)
        {
            if (string.IsNullOrWhiteSpace(content)) return BadRequest();
            rating = Math.Clamp(rating, 1, 5);

            var comment = new PlaceComment
            {
                PlaceId   = placeId,
                Content   = content,
                Rating    = rating,
                UserId    = _userManager.GetUserId(User)!,
                CreatedAt = DateTime.Now
            };

            _context.PlaceComments.Add(comment);
            await _context.SaveChangesAsync();

            // Invalidate AI summary cache vì có bình luận mới
            var place = await _repo.GetByIdAsync(placeId);
            if (place != null)
            {
                place.AiSummaryCache = null;
                place.AiSummaryCacheUpdatedAt = null;
                await _repo.UpdateAsync(place);
            }

            return RedirectToAction("Details", new { id = placeId });
        }

        // ─────────────────────────────────────
        // POST: /Place/VoteCommentHelpful
        // ─────────────────────────────────────
        [HttpPost]
        [Authorize]
        public async Task<IActionResult> VoteCommentHelpful(int commentId)
        {
            var userId = _userManager.GetUserId(User);
            if (userId == null)
                return Json(new { success = false, message = "Bạn cần đăng nhập để bình chọn." });

            var comment = await _context.PlaceComments.FindAsync(commentId);
            if (comment == null)
                return Json(new { success = false, message = "Không tìm thấy bình luận." });

            // Kiểm tra xem user đã vote chưa (chống duplicate ở tầng DB)
            bool alreadyVoted = await _context.CommentHelpfulVotes
                .AnyAsync(v => v.CommentId == commentId && v.UserId == userId);

            if (alreadyVoted)
                return Json(new { success = false, alreadyVoted = true, message = "Bạn đã bình chọn bình luận này rồi." });

            // Ghi nhận lượt vote mới
            _context.CommentHelpfulVotes.Add(new CommentHelpfulVote
            {
                CommentId = commentId,
                UserId    = userId,
                VotedAt   = DateTime.Now
            });

            comment.HelpfulCount++;
            await _context.SaveChangesAsync();

            return Json(new { success = true, newCount = comment.HelpfulCount });
        }

        // ─────────────────────────────────────
        // Images
        // ─────────────────────────────────────
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> AddImage(int placeId, Microsoft.AspNetCore.Http.IFormFile image)
        {
            var place = await _repo.GetByIdAsync(placeId);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            if (image == null || image.Length == 0)
            {
                TempData["Error"] = "Vui lòng chọn file ảnh hợp lệ.";
                return RedirectToAction("Details", new { id = placeId });
            }

            var ext = System.IO.Path.GetExtension(image.FileName);
            var fn  = Guid.NewGuid().ToString() + ext;
            var dir = System.IO.Path.Combine(
                System.IO.Directory.GetCurrentDirectory(), "wwwroot", "images", "places");
            if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);
            var filePath = System.IO.Path.Combine(dir, fn);
            using (var stream = new System.IO.FileStream(filePath, System.IO.FileMode.Create))
                await image.CopyToAsync(stream);

            var img = new PlaceImage { PlaceId = placeId, ImageUrl = $"/images/places/{fn}" };
            _context.PlaceImages.Add(img);
            await _context.SaveChangesAsync();

            TempData["Success"] = "Đã thêm ảnh thành công!";
            return RedirectToAction("Details", new { id = placeId });
        }

        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> DeleteImage(int imageId, int placeId)
        {
            var img = await _context.PlaceImages.FindAsync(imageId);
            if (img == null) return NotFound();

            var place = await _repo.GetByIdAsync(placeId);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            if (!string.IsNullOrEmpty(img.ImageUrl))
            {
                var physPath = System.IO.Path.Combine(
                    System.IO.Directory.GetCurrentDirectory(), "wwwroot",
                    img.ImageUrl.TrimStart('/').Replace('/', System.IO.Path.DirectorySeparatorChar));
                if (System.IO.File.Exists(physPath))
                    System.IO.File.Delete(physPath);
            }

            _context.PlaceImages.Remove(img);
            await _context.SaveChangesAsync();

            TempData["Success"] = "Đã xóa ảnh!";
            return RedirectToAction("Details", new { id = placeId });
        }
    }
}
