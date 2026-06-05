using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity.UI.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace DACS.Services
{
    public class EmailSender : IEmailSender
    {
        private readonly ILogger<EmailSender> _logger;
        private readonly IConfiguration _configuration;
        private readonly IWebHostEnvironment _env;
        private static readonly HttpClient _httpClient = new HttpClient();

        public EmailSender(ILogger<EmailSender> logger, IConfiguration configuration, IWebHostEnvironment env)
        {
            _logger = logger;
            _configuration = configuration;
            _env = env;
        }

        public Task SendEmailAsync(string email, string subject, string htmlMessage)
        {
            _ = Task.Run(async () =>
            {
                try
                {
                    var apiKey = _configuration["BrevoApiKey"];
                    if (!string.IsNullOrEmpty(apiKey))
                    {
                        await SendViaBrevoApiAsync(email, subject, htmlMessage, apiKey);
                    }
                    else
                    {
                        _logger.LogWarning("BrevoApiKey chưa được cấu hình. Lưu email ra file HTML.");
                        await WriteEmailToLocalHtmlAsync(email, subject, htmlMessage);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Lỗi nghiêm trọng trong EmailSender khi gửi tới {Email}", email);
                    await WriteEmailToLocalHtmlAsync(email, subject, htmlMessage);
                }
            });

            return Task.CompletedTask;
        }

        private async Task SendViaBrevoApiAsync(string email, string subject, string htmlMessage, string apiKey)
        {
            var senderEmail = _configuration["BrevoSenderEmail"] ?? "vietlecong2108@gmail.com";
            var senderName = _configuration["BrevoSenderName"] ?? "RestNDine";

            var payload = new
            {
                sender = new { email = senderEmail, name = senderName },
                to = new[] { new { email = email } },
                subject = subject,
                htmlContent = htmlMessage
            };

            var json = JsonSerializer.Serialize(payload);
            var request = new HttpRequestMessage(HttpMethod.Post, "https://api.brevo.com/v3/smtp/email");
            request.Headers.Add("api-key", apiKey);
            request.Content = new StringContent(json, Encoding.UTF8, "application/json");

            _logger.LogInformation("Đang gửi email tới {Email} qua Brevo API", email);

            var response = await _httpClient.SendAsync(request).WaitAsync(TimeSpan.FromSeconds(15));
            var responseBody = await response.Content.ReadAsStringAsync();

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Gửi email thành công tới {Email} qua Brevo API", email);
            }
            else
            {
                _logger.LogError("Brevo API lỗi {StatusCode}: {Body}", (int)response.StatusCode, responseBody);
                await WriteEmailToLocalHtmlAsync(email, subject, htmlMessage);
            }
        }

        private async Task WriteEmailToLocalHtmlAsync(string email, string subject, string htmlMessage)
        {
            try
            {
                var emailDir = Path.Combine(_env.WebRootPath, "sent_emails");
                Directory.CreateDirectory(emailDir);

                var fileName = $"email-{Guid.NewGuid()}.html";
                var filePath = Path.Combine(emailDir, fileName);

                var content = $@"<!DOCTYPE html>
<html lang=""vi"">
<head><meta charset=""utf-8""/><title>{subject}</title></head>
<body>
<p><strong>To:</strong> {email}</p>
<p><strong>Subject:</strong> {subject}</p>
<p><strong>Sent At:</strong> {DateTime.Now:dd/MM/yyyy HH:mm:ss}</p>
<hr/>
{htmlMessage}
</body>
</html>";

                await File.WriteAllTextAsync(filePath, content);
                _logger.LogWarning("[EMAIL FALLBACK] Lưu email tới {Email} tại /sent_emails/{FileName}", email, fileName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Không thể lưu email fallback: {Message}", ex.Message);
            }
        }
    }
}
