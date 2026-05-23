using System.Collections.Generic;
using System.Threading.Tasks;

namespace DACS.Services
{
    public interface IAiSummaryService
    {
        Task<string> SummarizeReviewsAsync(string placeName, IEnumerable<string> reviews);
    }
}
