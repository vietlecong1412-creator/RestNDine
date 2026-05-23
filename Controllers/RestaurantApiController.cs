using DACS.Models;
using DACS.Repositories;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace DACS.Controllers
{
    [ApiController]
    [Route("api/restaurant")]
    public class RestaurantApiController : ControllerBase
    {
        private readonly IRestaurantRepository _repo;

        public RestaurantApiController(IRestaurantRepository repo)
        {
            _repo = repo;
        }

        // GET: /api/restaurant
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Restaurant>>> GetRestaurants()
        {
            var restaurants = await _repo.GetApprovedOnlyAsync();
            return Ok(restaurants);
        }

        // GET: /api/restaurant/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Restaurant>> GetRestaurant(int id)
        {
            var r = await _repo.GetByIdAsync(id);
            if (r == null) return NotFound();
            return Ok(r);
        }

        // GET: /api/restaurant/owner/{ownerId}
        [HttpGet("owner/{ownerId}")]
        public async Task<ActionResult<IEnumerable<Restaurant>>> GetByOwner(string ownerId)
        {
            var list = await _repo.GetByOwnerIdAsync(ownerId);
            return Ok(list);
        }

        // POST: /api/restaurant
        [HttpPost]
        public async Task<ActionResult<Restaurant>> CreateRestaurant([FromBody] Restaurant r)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            
            await _repo.AddAsync(r);
            return CreatedAtAction(nameof(GetRestaurant), new { id = r.Id }, r);
        }

        // DELETE: /api/restaurant/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteRestaurant(int id)
        {
            var existing = await _repo.GetByIdAsync(id);
            if (existing == null) return NotFound();
            
            await _repo.DeleteAsync(id);
            return NoContent();
        }
    }
}
