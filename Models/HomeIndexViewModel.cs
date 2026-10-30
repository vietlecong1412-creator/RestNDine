using System.Collections.Generic;

namespace DACS.Models
{
    public class HomeIndexViewModel
    {
        public IEnumerable<PlaceMapDto> Places { get; set; } = new List<PlaceMapDto>();
    }
}
