using DACS.Data;
using DACS.Helpers;
using DACS.Models;
using Microsoft.EntityFrameworkCore;

namespace DACS.Services
{
    public enum BannerPaymentOutcome
    {
        InvalidSignature,
        NotFound,
        InvalidAmount,
        AlreadyProcessed,
        Paid,
        PaidNotApplied,
        Failed
    }

    public record BannerPaymentResult(
        BannerPaymentOutcome Outcome,
        int? PlaceId = null,
        string? PlaceName = null,
        string? ResponseCode = null,
        BannerPaymentStatus? Status = null);

    /// <summary>
    /// Tạo giao dịch banner VNPay và xử lý kết quả trả về. Return URL (trình duyệt) và IPN (server VNPay)
    /// dùng chung <see cref="ProcessCallbackAsync"/>, đến trước hay sau đều chỉ xử lý một lần.
    /// </summary>
    public class BannerPaymentService
    {
        public const long BannerPriceVnd = 100_000;

        private readonly ApplicationDbContext _context;
        private readonly VnPayService _vnPayService;
        private readonly ILogger<BannerPaymentService> _logger;

        public BannerPaymentService(
            ApplicationDbContext context,
            VnPayService vnPayService,
            ILogger<BannerPaymentService> logger)
        {
            _context = context;
            _vnPayService = vnPayService;
            _logger = logger;
        }

        public static bool CanRequestBanner(Place place) =>
            place.BannerStatus == BannerStatus.None || place.BannerStatus == BannerStatus.Rejected;

        /// <summary>Lưu giao dịch ở trạng thái Pending và trả về URL thanh toán. Chưa thay đổi gì trên Place.</summary>
        public async Task<string> CreateCheckoutAsync(HttpContext httpContext, int placeId, string? userId, string pendingBannerUrl)
        {
            var payment = new BannerPayment
            {
                TxnRef = "BN" + Guid.NewGuid().ToString("N"),
                PlaceId = placeId,
                UserId = userId,
                Amount = BannerPriceVnd,
                PendingBannerUrl = pendingBannerUrl
            };
            _context.BannerPayments.Add(payment);
            await _context.SaveChangesAsync();

            return _vnPayService.CreatePaymentUrl(httpContext, new VnPayPaymentRequest
            {
                OrderId = payment.TxnRef,
                OrderInfo = $"Quang cao banner Place {placeId}",
                Amount = payment.Amount,
                CreatedAt = DateTime.UtcNow.AddHours(7) // VNPay yêu cầu giờ Việt Nam, kể cả khi server chạy UTC
            });
        }

        public async Task<BannerPaymentResult> ProcessCallbackAsync(IQueryCollection query)
        {
            if (!_vnPayService.ValidateSignature(query, out var responseCode))
                return new BannerPaymentResult(BannerPaymentOutcome.InvalidSignature);

            var txnRef = query["vnp_TxnRef"].ToString();
            var payment = await _context.BannerPayments.AsNoTracking()
                .Include(p => p.Place)
                .FirstOrDefaultAsync(p => p.TxnRef == txnRef);
            if (payment == null)
                return new BannerPaymentResult(BannerPaymentOutcome.NotFound, ResponseCode: responseCode);

            var placeName = payment.Place?.Name;

            // vnp_Amount = số tiền * 100
            if (!long.TryParse(query["vnp_Amount"], out var amount) || amount != payment.Amount * 100)
            {
                _logger.LogError("VNPay sai số tiền cho {TxnRef}: nhận {Amount}, cần {Expected}",
                    txnRef, query["vnp_Amount"].ToString(), payment.Amount * 100);
                return new BannerPaymentResult(BannerPaymentOutcome.InvalidAmount, payment.PlaceId, placeName, responseCode);
            }

            bool success = responseCode == "00" && query["vnp_TransactionStatus"] == "00";
            var newStatus = success ? BannerPaymentStatus.Paid : BannerPaymentStatus.Failed;
            var transactionNo = query["vnp_TransactionNo"].ToString();
            var now = DateTime.UtcNow;

            await using var tx = await _context.Database.BeginTransactionAsync();

            // Cập nhật có điều kiện: request song song hoặc URL dùng lại sẽ không khớp dòng nào
            var claimed = await _context.BannerPayments
                .Where(p => p.Id == payment.Id && p.Status == BannerPaymentStatus.Pending)
                .ExecuteUpdateAsync(s => s
                    .SetProperty(p => p.Status, newStatus)
                    .SetProperty(p => p.ResponseCode, responseCode)
                    .SetProperty(p => p.VnpTransactionNo, transactionNo)
                    .SetProperty(p => p.ProcessedAt, now));
            if (claimed == 0)
            {
                var currentStatus = await _context.BannerPayments.AsNoTracking()
                    .Where(p => p.Id == payment.Id)
                    .Select(p => p.Status)
                    .FirstAsync();
                return new BannerPaymentResult(BannerPaymentOutcome.AlreadyProcessed, payment.PlaceId, placeName, responseCode, currentStatus);
            }

            if (!success)
            {
                await tx.CommitAsync();
                ImageUpload.TryDelete(payment.PendingBannerUrl);
                return new BannerPaymentResult(BannerPaymentOutcome.Failed, payment.PlaceId, placeName, responseCode);
            }

            // Chỉ áp dụng khi Place vẫn được phép đặt banner (có thể đã có giao dịch khác áp dụng trước)
            var proofUrl = $"vnpay:{txnRef}";
            var applied = await _context.Places
                .Where(p => p.Id == payment.PlaceId
                    && (p.BannerStatus == BannerStatus.None || p.BannerStatus == BannerStatus.Rejected))
                .ExecuteUpdateAsync(s => s
                    .SetProperty(p => p.BannerUrl, payment.PendingBannerUrl)
                    .SetProperty(p => p.PaymentProofUrl, proofUrl)
                    .SetProperty(p => p.BannerStatus, BannerStatus.PendingPayment));

            await tx.CommitAsync();

            if (applied == 0)
            {
                // Tiền đã nhận nhưng Place đã có banner khác: giữ giao dịch và ảnh để Admin xử lý
                _logger.LogError("Giao dịch {TxnRef} đã thanh toán nhưng Place {PlaceId} không còn ở trạng thái đặt banner.",
                    txnRef, payment.PlaceId);
                return new BannerPaymentResult(BannerPaymentOutcome.PaidNotApplied, payment.PlaceId, placeName, responseCode);
            }

            // Xóa ảnh còn sót lại từ lần đặt trước (nếu có)
            var oldBannerUrl = payment.Place?.BannerUrl;
            if (oldBannerUrl != payment.PendingBannerUrl)
                ImageUpload.TryDelete(oldBannerUrl);

            return new BannerPaymentResult(BannerPaymentOutcome.Paid, payment.PlaceId, placeName, responseCode);
        }
    }
}
