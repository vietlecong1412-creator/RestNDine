using DACS.Models;
using DACS.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace DACS.Controllers
{
    [ApiController]
    [Route("api/places")]
    public class PlaceApiController : ControllerBase
    {
        private readonly IPlaceRepository _repo;

        public PlaceApiController(IPlaceRepository repo)
        {
            _repo = repo;
        }

        // GET: /api/places
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Place>>> GetPlaces([FromQuery] int? categoryId)
        {
            if (categoryId.HasValue)
            {
                var byCategory = await _repo.GetByCategoryAsync(categoryId.Value);
                return Ok(byCategory);
            }

            var all = await _repo.GetApprovedOnlyAsync();
            return Ok(all);
        }

        // GET: /api/places/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Place>> GetPlace(int id)
        {
            var place = await _repo.GetByIdAsync(id);
            if (place == null) return NotFound();
            return Ok(place);
        }

        // GET: /api/places/owner/{ownerId}
        [HttpGet("owner/{ownerId}")]
        public async Task<ActionResult<IEnumerable<Place>>> GetByOwner(string ownerId)
        {
            var list = await _repo.GetByOwnerIdAsync(ownerId);
            return Ok(list);
        }

        // POST: /api/places
        [HttpPost]
        public async Task<ActionResult<Place>> CreatePlace([FromBody] Place place)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            await _repo.AddAsync(place);
            return CreatedAtAction(nameof(GetPlace), new { id = place.Id }, place);
        }

        // DELETE: /api/places/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeletePlace(int id)
        {
            var existing = await _repo.GetByIdAsync(id);
            if (existing == null) return NotFound();
            await _repo.DeleteAsync(id);
            return NoContent();
        }
    }
}
