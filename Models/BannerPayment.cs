using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Identity;

namespace DACS.Models
{
    public enum BannerPaymentStatus
    {
        Pending = 0,
        Paid = 1,
        Failed = 2
    }

    /// <summary>
    /// Một giao dịch VNPay mua banner. Ảnh banner chỉ được áp dụng vào Place khi giao dịch thành công,
    /// và mỗi giao dịch chỉ được xử lý một lần nên không thể mở lại URL cũ để tạo yêu cầu mới.
    /// </summary>
    public class BannerPayment
    {
        public int Id { get; set; }

        /// <summary>Mã đơn gửi sang VNPay (vnp_TxnRef).</summary>
        [Required]
        [MaxLength(64)]
        public string TxnRef { get; set; } = string.Empty;

        public int PlaceId { get; set; }

        [ForeignKey("PlaceId")]
        public virtual Place? Place { get; set; }

        public string? UserId { get; set; }

        [ForeignKey("UserId")]
        public virtual IdentityUser? User { get; set; }

        /// <summary>Số tiền (VNĐ).</summary>
        public long Amount { get; set; }

        /// <summary>Ảnh banner chờ áp dụng sau khi thanh toán thành công.</summary>
        [Required]
        public string PendingBannerUrl { get; set; } = string.Empty;

        public BannerPaymentStatus Status { get; set; } = BannerPaymentStatus.Pending;

        public string? ResponseCode { get; set; }

        public string? VnpTransactionNo { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? ProcessedAt { get; set; }
    }
}
