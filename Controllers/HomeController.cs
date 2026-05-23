using DACS.Models;
using DACS.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace DACS.Controllers
{
    public class HomeController : Controller
    {
        private readonly IRestaurantRepository _restaurantRepo;
        private readonly IHotelRepository _hotelRepo;

        public HomeController(IRestaurantRepository restaurantRepo, IHotelRepository hotelRepo)
        {
            _restaurantRepo = restaurantRepo;
            _hotelRepo = hotelRepo;
        }

        public async Task<IActionResult> Index()
        {
            var model = new HomeIndexViewModel
            {
                Restaurants = await _restaurantRepo.GetApprovedOnlyAsync(),
                Hotels = await _hotelRepo.GetApprovedOnlyAsync()
            };
            return View(model);
        }
    }
}
