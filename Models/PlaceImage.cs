using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DACS.Models
{
    public class PlaceImage
    {
        public int Id { get; set; }

        [Required]
        public string ImageUrl { get; set; } = string.Empty;

        public int PlaceId { get; set; }

        [ForeignKey("PlaceId")]
        public virtual Place? Place { get; set; }
    }
}
