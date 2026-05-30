using DACS.Models;
using DACS.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace DACS.Controllers
{
    public class HomeController : Controller
    {
        private readonly IPlaceRepository _placeRepo;

        public HomeController(IPlaceRepository placeRepo)
        {
            _placeRepo = placeRepo;
        }

        public async Task<IActionResult> Index()
        {
            var approvedPlaces = await _placeRepo.GetApprovedOnlyAsync();
            
            var model = new HomeIndexViewModel
            {
                Places = approvedPlaces.Select(p => new PlaceDto
                {
                    Id = p.Id,
                    Name = p.Name,
                    Address = p.Address,
                    Latitude = p.Latitude,
                    Longitude = p.Longitude,
                    Description = p.Description,
                    ImageUrl = p.ImageUrl,
                    PhoneNumber = p.PhoneNumber,
                    PriceRange = p.PriceRange,
                    BannerUrl = p.BannerUrl,
                    PaymentProofUrl = p.PaymentProofUrl,
                    BannerStatus = p.BannerStatus,
                    IsApproved = p.IsApproved,
                    CategoryId = p.CategoryId,
                    StarRating = p.StarRating,
                    Amenities = p.Amenities
                }).ToList()
            };
            return View(model);
        }
    }
}
