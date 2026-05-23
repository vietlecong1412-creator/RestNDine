using DACS.Data;
using DACS.Models;
using DACS.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

using Microsoft.AspNetCore.Http;
using System.IO;

namespace DACS.Areas.Admin.Controllers
{
    [Area("Admin")]
    [Authorize(Roles = "Admin")]
    public class RestaurantController : Controller
    {
        private readonly IRestaurantRepository _repo;

        public RestaurantController(IRestaurantRepository repo)
        {
            _repo = repo;
        }

        public async Task<IActionResult> Index()
        {
            var all = await _repo.GetAllAsync();
            return View(all.OrderByDescending(r => r.Id).ToList());
        }

        public IActionResult Create()
        {
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Create(Restaurant r, IFormFile? image)
        {
            if (ModelState.IsValid)
            {
                if (image != null && image.Length > 0)
                {
                    var fileExtension = Path.GetExtension(image.FileName);
                    var newFileName = Guid.NewGuid().ToString() + fileExtension;
                    var path = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images", "restaurants", newFileName);
                    
                    var dir = Path.GetDirectoryName(path);
                    if (!Directory.Exists(dir))
                    {
                        Directory.CreateDirectory(dir!);
                    }

                    using (var stream = new FileStream(path, FileMode.Create))
                    {
                        await image.CopyToAsync(stream);
                    }
                    r.ImageUrl = $"/images/restaurants/{newFileName}";
                }

                await _repo.AddAsync(r);
                return RedirectToAction("Index");
            }
            return View(r);
        }

        public async Task<IActionResult> Delete(int id)
        {
            await _repo.DeleteAsync(id);
            return RedirectToAction("Index");
        }

        [HttpPost]
        public async Task<IActionResult> Approve(int id)
        {
            var r = await _repo.GetByIdAsync(id);
            if (r != null)
            {
                r.IsApproved = true;
                await _repo.UpdateAsync(r);
            }
            return RedirectToAction("Index");
        }

        // GET: /Admin/Restaurant/BannerRequests
        public async Task<IActionResult> BannerRequests()
        {
            var all = await _repo.GetAllAsync();
            var pending = all
                .Where(r => r.BannerStatus == DACS.Models.BannerStatus.PendingPayment)
                .OrderByDescending(r => r.Id)
                .ToList();
            return View(pending);
        }

        // POST: /Admin/Restaurant/ApproveBanner
        [HttpPost]
        public async Task<IActionResult> ApproveBanner(int id)
        {
            var r = await _repo.GetByIdAsync(id);
            if (r != null)
            {
                r.BannerStatus = DACS.Models.BannerStatus.Active;
                await _repo.UpdateAsync(r);
                TempData["Success"] = $"Đã duyệt banner cho \"{r.Name}\"!";
            }
            return RedirectToAction("BannerRequests");
        }

        // POST: /Admin/Restaurant/RejectBanner
        [HttpPost]
        public async Task<IActionResult> RejectBanner(int id)
        {
            var r = await _repo.GetByIdAsync(id);
            if (r != null)
            {
                r.BannerStatus = DACS.Models.BannerStatus.Rejected;
                r.BannerUrl = null;
                r.PaymentProofUrl = null;
                await _repo.UpdateAsync(r);
                TempData["Error"] = $"Đã từ chối banner cho \"{r.Name}\".";
            }
            return RedirectToAction("BannerRequests");
        }
    }
}
