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
            var model = new HomeIndexViewModel
            {
                Places = await _placeRepo.GetApprovedForMapAsync()
            };
            return View(model);
        }
    }
}
