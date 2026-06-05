using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Identity;

namespace DACS.Models
{
    public class ChatMessage
    {
        public int Id { get; set; }

        public int PlaceId { get; set; }

        [ForeignKey("PlaceId")]
        public virtual Place? Place { get; set; }

        [Required]
        public string SenderId { get; set; } = string.Empty;

        [ForeignKey("SenderId")]
        public virtual IdentityUser? Sender { get; set; }

        [Required]
        public string ReceiverId { get; set; } = string.Empty;

        [ForeignKey("ReceiverId")]
        public virtual IdentityUser? Receiver { get; set; }

        [Required]
        public string Content { get; set; } = string.Empty;

        public DateTime SentAt { get; set; } = DateTime.UtcNow;

        public bool IsRead { get; set; } = false;
    }
}
