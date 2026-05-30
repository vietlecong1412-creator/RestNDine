using DACS.Data;
using DACS.Models;
using DACS.Repositories;
using Microsoft.AspNetCore.Authorization;
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

        public PlaceController(IPlaceRepository repo, ApplicationDbContext context)
        {
            _repo = repo;
            _context = context;
        }

        public async Task<IActionResult> Index()
        {
            var all = await _repo.GetAllAsync();
            return View(all.OrderByDescending(p => p.Id).ToList());
        }

        public async Task<IActionResult> Create()
        {
            ViewBag.Categories = new SelectList(
                await _context.PlaceCategories.ToListAsync(), "Id", "Name");
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Create(Place place, IFormFile? image)
        {
            if (ModelState.IsValid)
            {
                if (image != null && image.Length > 0)
                {
                    var fileExtension = Path.GetExtension(image.FileName);
                    var newFileName = Guid.NewGuid().ToString() + fileExtension;
                    var dir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images", "places");
                    if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
                    var path = Path.Combine(dir, newFileName);
                    using (var stream = new FileStream(path, FileMode.Create))
                        await image.CopyToAsync(stream);
                    place.ImageUrl = $"/images/places/{newFileName}";
                }

                await _repo.AddAsync(place);
                return RedirectToAction("Index");
            }

            ViewBag.Categories = new SelectList(
                await _context.PlaceCategories.ToListAsync(), "Id", "Name", place.CategoryId);
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
            var all = await _repo.GetAllAsync();
            var pending = all
                .Where(p => p.BannerStatus == BannerStatus.PendingPayment)
                .OrderByDescending(p => p.Id)
                .ToList();
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
            }
            return RedirectToAction("BannerRequests");
        }
    }
}
