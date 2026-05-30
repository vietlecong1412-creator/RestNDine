using System.Collections.Generic;

namespace DACS.Models
{
    public class HomeIndexViewModel
    {
        public IEnumerable<PlaceDto> Places { get; set; } = new List<PlaceDto>();
    }
}
