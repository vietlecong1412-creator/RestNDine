using DACS.Models;
using DACS.Repositories;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace DACS.Controllers
{
    [ApiController]
    [Route("api/hotel")]
    public class HotelApiController : ControllerBase
    {
        private readonly IHotelRepository _repo;

        public HotelApiController(IHotelRepository repo)
        {
            _repo = repo;
        }

        // GET: /api/hotel
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Hotel>>> GetHotels()
        {
            var hotels = await _repo.GetApprovedOnlyAsync();
            return Ok(hotels);
        }

        // GET: /api/hotel/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Hotel>> GetHotel(int id)
        {
            var h = await _repo.GetByIdAsync(id);
            if (h == null) return NotFound();
            return Ok(h);
        }

        // GET: /api/hotel/owner/{ownerId}
        [HttpGet("owner/{ownerId}")]
        public async Task<ActionResult<IEnumerable<Hotel>>> GetByOwner(string ownerId)
        {
            var list = await _repo.GetByOwnerIdAsync(ownerId);
            return Ok(list);
        }

        // POST: /api/hotel
        [HttpPost]
        public async Task<ActionResult<Hotel>> CreateHotel([FromBody] Hotel h)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);
            
            await _repo.AddAsync(h);
            return CreatedAtAction(nameof(GetHotel), new { id = h.Id }, h);
        }

        // DELETE: /api/hotel/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteHotel(int id)
        {
            var existing = await _repo.GetByIdAsync(id);
            if (existing == null) return NotFound();
            
            await _repo.DeleteAsync(id);
            return NoContent();
        }
    }
}
