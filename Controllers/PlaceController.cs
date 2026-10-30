using System;
using DACS.Helpers;
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
        private readonly PlaceReviewService _reviews;
        private readonly BannerPaymentService _bannerPayments;

        public PlaceController(
            IPlaceRepository repo,
            UserManager<IdentityUser> userManager,
            DACS.Data.ApplicationDbContext context,
            PlaceReviewService reviews,
            BannerPaymentService bannerPayments)
        {
            _repo = repo;
            _userManager = userManager;
            _context = context;
            _reviews = reviews;
            _bannerPayments = bannerPayments;
        }

        // ─────────────────────────────────────
        // GET: /Place/Details/5
        // ─────────────────────────────────────
        public async Task<IActionResult> Details(int id)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place == null || !PlaceAccess.CanView(place, User)) return NotFound();

            // ── AI Summary Cache Logic ──
            if (PlaceReviewService.IsAiCacheValid(place))
            {
                ViewBag.AiSummary = place.AiSummaryCache;
                var sentiment = PlaceReviewService.CountSentiment(place.Comments);
                ViewBag.ChartPositive = sentiment.Positive;
                ViewBag.ChartNeutral  = sentiment.Neutral;
                ViewBag.ChartNegative = sentiment.Negative;
            }
            else
            {
                // Gán null để thông báo giao diện tiến hành gọi AJAX tải ngầm bất đồng bộ
                ViewBag.AiSummary = null;
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
        // GET: /Place/GetAiSummary
        // ─────────────────────────────────────
        [HttpGet]
        public async Task<IActionResult> GetAiSummary(int placeId, bool forceRefresh = false)
        {
            var place = await _repo.GetByIdAsync(placeId);
            if (place == null || !PlaceAccess.CanView(place, User))
                return Json(new { success = false, message = "Không tìm thấy địa điểm." });

            // Chỉ chủ địa điểm và Admin được yêu cầu phân tích lại
            forceRefresh = forceRefresh && PlaceAccess.CanManage(place, User);

            var ai = await _reviews.GetAiSummaryAsync(place, forceRefresh);
            var sentiment = PlaceReviewService.CountSentiment(place.Comments);
            return Json(new
            {
                success = true,
                html = SafeMarkdown.ToHtml(ai.Summary),
                chartData = new { positive = sentiment.Positive, neutral = sentiment.Neutral, negative = sentiment.Negative }
            });
        }

        // ─────────────────────────────────────
        // GET: /Place/Create
        // ─────────────────────────────────────
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Create()
        {
            ViewBag.AllCategories = await _context.PlaceCategories.ToListAsync();
            return View();
        }

        // POST: /Place/Create
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Create(Place place, int[] selectedCategoryIds, Microsoft.AspNetCore.Http.IFormFile? image)
        {
            ModelState.Remove("Categories");
            bool hasImage = image != null && image.Length > 0;
            if (hasImage && await ImageUpload.ValidateAsync(image) is string imageError)
                ModelState.AddModelError(string.Empty, imageError);

            if (ModelState.IsValid)
            {
                place.OwnerId = _userManager.GetUserId(User);
                place.IsApproved = User.IsInRole("Admin");

                if (hasImage)
                    place.ImageUrl = await ImageUpload.SaveAsync(image!, "places");

                if (selectedCategoryIds.Length > 0)
                {
                    var categories = await _context.PlaceCategories
                        .Where(c => selectedCategoryIds.Contains(c.Id))
                        .ToListAsync();
                    foreach (var cat in categories)
                        place.Categories.Add(cat);
                }

                await _repo.AddAsync(place);

                if (User.IsInRole("Admin"))
                    return RedirectToAction("Index", "Place", new { area = "Admin" });

                TempData["Success"] = "Yêu cầu thêm địa điểm đã được gửi và đang chờ Admin duyệt.";
                return RedirectToAction("Index", "Home");
            }

            ViewBag.AllCategories = await _context.PlaceCategories.ToListAsync();
            ViewBag.SelectedCategoryIds = selectedCategoryIds;
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

            ViewBag.AllCategories = await _context.PlaceCategories.ToListAsync();
            ViewBag.SelectedCategoryIds = place.Categories.Select(c => c.Id).ToArray();
            return View(place);
        }

        // POST: /Place/Edit/5
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> Edit(int id, Place updated, int[] selectedCategoryIds, Microsoft.AspNetCore.Http.IFormFile? image)
        {
            if (id != updated.Id) return BadRequest();

            var place = await _repo.GetByIdAsync(id);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            ModelState.Remove("Categories");
            bool hasImage = image != null && image.Length > 0;
            if (hasImage && await ImageUpload.ValidateAsync(image) is string imageError)
                ModelState.AddModelError(string.Empty, imageError);

            if (ModelState.IsValid)
            {
                if (hasImage)
                    place.ImageUrl = await ImageUpload.SaveAsync(image!, "places");

                place.Name         = updated.Name;
                place.Address      = updated.Address;
                place.Description  = updated.Description;
                place.Latitude     = updated.Latitude;
                place.Longitude    = updated.Longitude;
                place.PriceRange   = updated.PriceRange;
                place.PhoneNumber  = updated.PhoneNumber;
                place.StarRating   = updated.StarRating;
                place.Amenities    = updated.Amenities;
                place.OpeningHours = updated.OpeningHours;
                place.Website      = updated.Website;
                place.Tags         = updated.Tags;

                // Cập nhật categories: xóa cũ, thêm mới
                place.Categories.Clear();
                if (selectedCategoryIds.Length > 0)
                {
                    var categories = await _context.PlaceCategories
                        .Where(c => selectedCategoryIds.Contains(c.Id))
                        .ToListAsync();
                    foreach (var cat in categories)
                        place.Categories.Add(cat);
                }

                await _repo.UpdateAsync(place);
                TempData["Success"] = "Cập nhật thông tin địa điểm thành công!";

                if (User.IsInRole("Admin"))
                    return RedirectToAction("Index", "Place", new { area = "Admin" });

                return RedirectToAction(nameof(MyPlaces));
            }

            ViewBag.AllCategories = await _context.PlaceCategories.ToListAsync();
            ViewBag.SelectedCategoryIds = selectedCategoryIds;
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

            if (!BannerPaymentService.CanRequestBanner(place) && !User.IsInRole("Admin"))
            {
                TempData["Error"] = "Địa điểm này đang có banner hoặc yêu cầu banner chờ duyệt.";
                return RedirectToAction("Details", new { id });
            }

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

            if (!BannerPaymentService.CanRequestBanner(place) && !User.IsInRole("Admin"))
            {
                TempData["Error"] = "Địa điểm này đang có banner hoặc yêu cầu banner chờ duyệt.";
                return RedirectToAction("Details", new { id });
            }

            // Kiểm tra cả 2 file trước khi lưu để không ghi banner khi thiếu biên lai
            if (await ImageUpload.ValidateAsync(bannerImage) is string bannerError)
            {
                TempData["Error"] = "Ảnh banner: " + bannerError;
                return RedirectToAction("Details", new { id });
            }
            if (await ImageUpload.ValidateAsync(paymentProof) is string proofError)
            {
                TempData["Error"] = "Ảnh biên lai chuyển khoản: " + proofError;
                return RedirectToAction("Details", new { id });
            }

            place.BannerUrl       = await ImageUpload.SaveAsync(bannerImage, "banners");
            place.PaymentProofUrl = await ImageUpload.SaveAsync(paymentProof, "payment");
            place.BannerStatus    = User.IsInRole("Admin") ? BannerStatus.Active : BannerStatus.PendingPayment;
            await _repo.UpdateAsync(place);
            TempData["Success"] = User.IsInRole("Admin")
                ? "Banner đã được kích hoạt!"
                : "Yêu cầu banner đã được gửi và đang chờ Admin xác nhận thanh toán.";

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

        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> UploadBannerImage(int id, Microsoft.AspNetCore.Http.IFormFile bannerImage)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            if (place.BannerStatus != BannerStatus.Active && !User.IsInRole("Admin"))
            {
                TempData["Error"] = "Chiến dịch quảng cáo không hoạt động.";
                return RedirectToAction("Details", new { id });
            }

            if (await ImageUpload.ValidateAsync(bannerImage) is string bannerError)
            {
                TempData["Error"] = bannerError;
            }
            else
            {
                var newBannerUrl = await ImageUpload.SaveAsync(bannerImage, "banners");

                // Xóa ảnh cũ nếu có để tránh rác server
                if (!string.IsNullOrEmpty(place.BannerUrl))
                {
                    var oldPath = System.IO.Path.Combine(
                        System.IO.Directory.GetCurrentDirectory(), "wwwroot", place.BannerUrl.TrimStart('/'));
                    if (System.IO.File.Exists(oldPath))
                    {
                        try { System.IO.File.Delete(oldPath); } catch {}
                    }
                }

                place.BannerUrl = newBannerUrl;
                await _repo.UpdateAsync(place);
                TempData["Success"] = "Đã tải lên/cập nhật ảnh banner thành công!";
            }

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
            var place = await _repo.GetByIdAsync(placeId);
            if (place == null || !PlaceAccess.CanView(place, User)) return NotFound();

            await _reviews.AddCommentAsync(place, _userManager.GetUserId(User)!, content, rating);

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

            var vote = await _reviews.VoteHelpfulAsync(commentId, userId, User);
            return vote.Status switch
            {
                HelpfulVoteStatus.NotFound => Json(new { success = false, message = "Không tìm thấy bình luận." }),
                HelpfulVoteStatus.AlreadyVoted => Json(new { success = false, alreadyVoted = true, message = "Bạn đã bình chọn bình luận này rồi." }),
                _ => Json(new { success = true, newCount = vote.HelpfulCount })
            };
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

            if (await ImageUpload.ValidateAsync(image) is string imageError)
            {
                TempData["Error"] = imageError;
                return RedirectToAction("Details", new { id = placeId });
            }

            var img = new PlaceImage { PlaceId = placeId, ImageUrl = await ImageUpload.SaveAsync(image, "places") };
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

        // ─────────────────────────────────────
        // VNPay – Khởi tạo thanh toán
        // ─────────────────────────────────────
        [HttpPost]
        [Authorize(Roles = "Owner,Admin")]
        public async Task<IActionResult> VnpayCheckout(int id, Microsoft.AspNetCore.Http.IFormFile bannerImage)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place == null || (place.OwnerId != _userManager.GetUserId(User) && !User.IsInRole("Admin")))
                return Unauthorized();

            if (!BannerPaymentService.CanRequestBanner(place))
            {
                TempData["Error"] = "Địa điểm này đang có banner hoặc yêu cầu banner chờ duyệt.";
                return RedirectToAction("Details", new { id });
            }

            if (await ImageUpload.ValidateAsync(bannerImage) is string bannerError)
            {
                TempData["Error"] = bannerError;
                return RedirectToAction("Payment", new { id });
            }

            // Ảnh chỉ được gắn vào Place sau khi thanh toán thành công
            var pendingBannerUrl = await ImageUpload.SaveAsync(bannerImage, "banners");
            var paymentUrl = await _bannerPayments.CreateCheckoutAsync(
                HttpContext, id, _userManager.GetUserId(User), pendingBannerUrl);
            return Redirect(paymentUrl);
        }

        // ─────────────────────────────────────
        // VNPay – Callback (Return URL, qua trình duyệt người dùng)
        // ─────────────────────────────────────
        public async Task<IActionResult> VnpayReturn()
        {
            var result = await _bannerPayments.ProcessCallbackAsync(Request.Query);

            switch (result.Outcome)
            {
                case BannerPaymentOutcome.InvalidSignature:
                    TempData["Error"] = "Chữ ký không hợp lệ. Vui lòng liên hệ hỗ trợ.";
                    return RedirectToAction("Index", "Home");

                case BannerPaymentOutcome.NotFound:
                    TempData["Error"] = "Không xác định được đơn hàng.";
                    return RedirectToAction("Index", "Home");

                case BannerPaymentOutcome.InvalidAmount:
                    TempData["Error"] = "Số tiền giao dịch không khớp. Vui lòng liên hệ hỗ trợ.";
                    return RedirectToAction("Details", new { id = result.PlaceId });

                case BannerPaymentOutcome.AlreadyProcessed:
                    // IPN có thể đã xử lý trước, nên vẫn báo đúng kết quả của giao dịch
                    if (result.Status == BannerPaymentStatus.Paid)
                        TempData["Success"] = "Giao dịch này đã được ghi nhận thành công trước đó.";
                    else
                        TempData["Error"] = "Giao dịch này đã thất bại hoặc đã bị hủy. Vui lòng tạo giao dịch mới.";
                    return RedirectToAction("Details", new { id = result.PlaceId });

                case BannerPaymentOutcome.Paid:
                    TempData["Success"] = $"Thanh toán VNPay thành công! Yêu cầu banner của {result.PlaceName} đang chờ Admin phê duyệt.";
                    return RedirectToAction("Details", new { id = result.PlaceId });

                case BannerPaymentOutcome.PaidNotApplied:
                    TempData["Error"] = "Đã nhận thanh toán nhưng địa điểm đang có banner khác. Vui lòng liên hệ Admin để được hỗ trợ.";
                    return RedirectToAction("Details", new { id = result.PlaceId });

                default:
                    // Thanh toán thất bại hoặc bị hủy
                    TempData["Error"] = result.ResponseCode switch
                    {
                        "24" => "Giao dịch bị hủy bởi người dùng.",
                        "11" => "Giao dịch hết hạn. Vui lòng thử lại.",
                        "09" => "Thẻ/tài khoản chưa đăng ký dịch vụ.",
                        _    => $"Thanh toán thất bại (Mã lỗi: {result.ResponseCode})."
                    };
                    return RedirectToAction("Payment", new { id = result.PlaceId });
            }
        }

        // ─────────────────────────────────────
        // VNPay – IPN (server VNPay gọi trực tiếp, không phụ thuộc trình duyệt người dùng)
        // ─────────────────────────────────────
        [HttpGet]
        public async Task<IActionResult> VnpayIpn()
        {
            var result = await _bannerPayments.ProcessCallbackAsync(Request.Query);

            var (rspCode, message) = result.Outcome switch
            {
                BannerPaymentOutcome.InvalidSignature => ("97", "Invalid signature"),
                BannerPaymentOutcome.NotFound => ("01", "Order not found"),
                BannerPaymentOutcome.InvalidAmount => ("04", "Invalid amount"),
                BannerPaymentOutcome.AlreadyProcessed => ("02", "Order already confirmed"),
                _ => ("00", "Confirm Success")
            };

            // VNPay yêu cầu đúng tên trường RspCode/Message nên không dùng camelCase mặc định
            return Json(new { RspCode = rspCode, Message = message }, new System.Text.Json.JsonSerializerOptions());
        }
    }
}
