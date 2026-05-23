using System.Collections.Generic;

namespace DACS.Models
{
    public class HomeIndexViewModel
    {
        public IEnumerable<Restaurant> Restaurants { get; set; } = new List<Restaurant>();
        public IEnumerable<Hotel> Hotels { get; set; } = new List<Hotel>();
    }
}
