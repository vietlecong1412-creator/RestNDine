using System.Collections.Generic;

namespace DACS.Models
{
    public class HomeIndexViewModel
    {
        public IEnumerable<Place> Places { get; set; } = new List<Place>();
    }
}
