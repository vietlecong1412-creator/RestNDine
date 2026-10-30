using DACS.Data;
using DACS.Helpers;
using DACS.Models;
using DACS.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.UI.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Http;
using System.IO;

namespace DACS.Areas.Admin.Controllers
{
    [Area("Admin")]
    [Authorize(Roles = "Admin")]
    public class PlaceController : Controller
    {
        private readonly IPlaceRepository _repo;
        private readonly ApplicationDbContext _context;
        private readonly IEmailSender _emailSender;
        private readonly UserManager<IdentityUser> _userManager;

        public PlaceController(
            IPlaceRepository repo,
            ApplicationDbContext context,
            IEmailSender emailSender,
            UserManager<IdentityUser> userManager)
        {
            _repo        = repo;
            _context     = context;
            _emailSender = emailSender;
            _userManager = userManager;
        }

        public async Task<IActionResult> Index()
        {
            var all = await _repo.GetAllAsync();
            return View(all.OrderByDescending(p => p.Id).ToList());
        }

        public async Task<IActionResult> Create()
        {
            ViewBag.AllCategories = await _context.PlaceCategories.ToListAsync();
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Create(Place place, int[] selectedCategoryIds, IFormFile? image)
        {
            ModelState.Remove("Categories");
            bool hasImage = image != null && image.Length > 0;
            if (hasImage && await ImageUpload.ValidateAsync(image) is string imageError)
                ModelState.AddModelError(string.Empty, imageError);

            if (ModelState.IsValid)
            {
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
                return RedirectToAction("Index");
            }

            ViewBag.AllCategories = await _context.PlaceCategories.ToListAsync();
            ViewBag.SelectedCategoryIds = selectedCategoryIds;
            return View(place);
        }

        public async Task<IActionResult> Delete(int id)
        {
            await _repo.DeleteAsync(id);
            return RedirectToAction("Index");
        }

        [HttpPost]
        public async Task<IActionResult> Approve(int id)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place != null)
            {
                place.IsApproved = true;
                await _repo.UpdateAsync(place);
            }
            return RedirectToAction("Index");
        }

        // GET: /Admin/Place/BannerRequests
        public async Task<IActionResult> BannerRequests()
        {
            var pending = await _context.Places
                .AsNoTracking()
                .Include(p => p.Categories)
                .Where(p => p.BannerStatus == BannerStatus.PendingPayment)
                .OrderByDescending(p => p.Id)
                .ToListAsync();
            return View(pending);
        }

        // POST: /Admin/Place/ApproveBanner
        [HttpPost]
        public async Task<IActionResult> ApproveBanner(int id)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place != null)
            {
                place.BannerStatus = BannerStatus.Active;
                await _repo.UpdateAsync(place);
                TempData["Success"] = $"Đã duyệt banner cho \"{place.Name}\"!";

                // Gửi email thông báo cho Owner (bất đồng bộ, không block)
                _ = SendBannerApprovedEmailAsync(place);
            }
            return RedirectToAction("BannerRequests");
        }

        // POST: /Admin/Place/RejectBanner
        [HttpPost]
        public async Task<IActionResult> RejectBanner(int id)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place != null)
            {
                place.BannerStatus    = BannerStatus.Rejected;
                place.BannerUrl       = null;
                place.PaymentProofUrl = null;
                await _repo.UpdateAsync(place);
                TempData["Error"] = $"Đã từ chối banner cho \"{place.Name}\".";

                // Gửi email thông báo từ chối cho Owner (bất đồng bộ, không block)
                _ = SendBannerRejectedEmailAsync(place);
            }
            return RedirectToAction("BannerRequests");
        }

        // ─── Email helpers ────────────────────────────────────────────────────────

        private async Task SendBannerApprovedEmailAsync(Place place)
        {
            try
            {
                if (string.IsNullOrEmpty(place.OwnerId)) return;
                var owner = await _userManager.FindByIdAsync(place.OwnerId);
                if (owner == null || string.IsNullOrEmpty(owner.Email)) return;

                var subject = $"✅ Banner quảng cáo của \"{place.Name}\" đã được phê duyệt!";
                var html = $@"
<div style=""font-family:'Segoe UI',Arial,sans-serif;max-width:600px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);"">
  <div style=""background:linear-gradient(135deg,#ea580c,#f97316);padding:2rem 2rem 1.5rem;"">
    <div style=""font-size:2rem;margin-bottom:.5rem;"">🎉</div>
    <h1 style=""color:#fff;margin:0;font-size:1.4rem;font-weight:800;"">Banner đã được phê duyệt!</h1>
    <p style=""color:rgba(255,255,255,.85);margin:.4rem 0 0;font-size:.92rem;"">Tin vui từ đội ngũ RestNDine</p>
  </div>
  <div style=""padding:2rem;"">
    <p style=""color:#374151;font-size:.95rem;line-height:1.7;"">
      Xin chào <strong>{owner.UserName ?? owner.Email}</strong>,
    </p>
    <p style=""color:#374151;font-size:.95rem;line-height:1.7;"">
      Yêu cầu đăng banner quảng cáo cho địa điểm <strong style=""color:#ea580c;"">{place.Name}</strong>
      đã được Admin <strong>phê duyệt</strong>. Banner của bạn hiện đang <strong>hoạt động</strong>
      và sẽ xuất hiện trên trang chủ RestNDine.
    </p>
    <div style=""background:#fef3c7;border-left:4px solid #f59e0b;border-radius:8px;padding:1rem 1.2rem;margin:1.5rem 0;"">
      <p style=""margin:0;color:#92400e;font-size:.88rem;"">
        ⭐ <strong>Mẹo:</strong> Banner sẽ được hiển thị nổi bật trên trang bản đồ giúp thu hút thêm nhiều khách hàng!
      </p>
    </div>
    <a href=""/Place/Details/{place.Id}""
       style=""display:inline-block;background:linear-gradient(135deg,#ea580c,#f97316);color:#fff;text-decoration:none;padding:.75rem 1.75rem;border-radius:10px;font-weight:700;font-size:.92rem;margin-top:.5rem;"">
      📍 Xem địa điểm của bạn
    </a>
  </div>
  <div style=""background:#f9fafb;padding:1rem 2rem;border-top:1px solid #e5e7eb;font-size:.78rem;color:#9ca3af;text-align:center;"">
    © {DateTime.Now.Year} RestNDine · Bản đồ ẩm thực &amp; khách sạn
  </div>
</div>";

                await _emailSender.SendEmailAsync(owner.Email, subject, html);
            }
            catch (Exception ex)
            {
                // Log và bỏ qua lỗi email – không ảnh hưởng luồng chính
                Console.Error.WriteLine($"[Email] Lỗi gửi email duyệt banner: {ex.Message}");
            }
        }

        private async Task SendBannerRejectedEmailAsync(Place place)
        {
            try
            {
                if (string.IsNullOrEmpty(place.OwnerId)) return;
                var owner = await _userManager.FindByIdAsync(place.OwnerId);
                if (owner == null || string.IsNullOrEmpty(owner.Email)) return;

                var subject = $"❌ Yêu cầu banner của \"{place.Name}\" bị từ chối";
                var html = $@"
<div style=""font-family:'Segoe UI',Arial,sans-serif;max-width:600px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);"">
  <div style=""background:linear-gradient(135deg,#dc2626,#ef4444);padding:2rem 2rem 1.5rem;"">
    <div style=""font-size:2rem;margin-bottom:.5rem;"">⚠️</div>
    <h1 style=""color:#fff;margin:0;font-size:1.4rem;font-weight:800;"">Yêu cầu banner bị từ chối</h1>
    <p style=""color:rgba(255,255,255,.85);margin:.4rem 0 0;font-size:.92rem;"">Thông báo từ đội ngũ RestNDine</p>
  </div>
  <div style=""padding:2rem;"">
    <p style=""color:#374151;font-size:.95rem;line-height:1.7;"">
      Xin chào <strong>{owner.UserName ?? owner.Email}</strong>,
    </p>
    <p style=""color:#374151;font-size:.95rem;line-height:1.7;"">
      Rất tiếc, yêu cầu đăng banner quảng cáo cho địa điểm <strong style=""color:#dc2626;"">{place.Name}</strong>
      đã bị Admin <strong>từ chối</strong>.
    </p>
    <div style=""background:#fef2f2;border-left:4px solid #ef4444;border-radius:8px;padding:1rem 1.2rem;margin:1.5rem 0;"">
      <p style=""margin:0;color:#7f1d1d;font-size:.88rem;"">
        ℹ️ <strong>Lý do phổ biến:</strong> Nội dung banner không phù hợp với chính sách của RestNDine
        (vi phạm pháp luật, hình ảnh không rõ ràng, hoặc nội dung không liên quan đến địa điểm).
      </p>
    </div>
    <p style=""color:#374151;font-size:.92rem;line-height:1.7;"">
      Bạn có thể chỉnh sửa nội dung banner và gửi lại yêu cầu. Vui lòng đảm bảo banner
      tuân thủ đúng <strong>chính sách quảng cáo</strong> của RestNDine.
    </p>
    <a href=""/Place/Payment/{place.Id}""
       style=""display:inline-block;background:linear-gradient(135deg,#374151,#1f2937);color:#fff;text-decoration:none;padding:.75rem 1.75rem;border-radius:10px;font-weight:700;font-size:.92rem;margin-top:.5rem;"">
      🔄 Gửi lại yêu cầu banner
    </a>
  </div>
  <div style=""background:#f9fafb;padding:1rem 2rem;border-top:1px solid #e5e7eb;font-size:.78rem;color:#9ca3af;text-align:center;"">
    © {DateTime.Now.Year} RestNDine · Bản đồ ẩm thực &amp; khách sạn
  </div>
</div>";

                await _emailSender.SendEmailAsync(owner.Email, subject, html);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[Email] Lỗi gửi email từ chối banner: {ex.Message}");
            }
        }
    }
}
