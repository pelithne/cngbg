using Azure;
using Azure.Communication.Email;
using Serilog;

namespace EmailSender.MessageHandlers.RecipesNotifications;

public class RecipeEmailSender
{
    private readonly EmailClient _emailClient;

    // The email address of the domain registered with the Communication Services resource
    private readonly string _sender;

    private const string Subject = "Your Contoso Luxury Dinner Recipe";

    public RecipeEmailSender(IConfiguration configuration)
    {
        _emailClient = new EmailClient(configuration["AZURE_COMMUNICATION_CONNECTION_STRING"]);
        _sender = configuration["AZURE_COMMUNICATION_FROM_ADDRESS"];
    }

    public async Task<bool> SendEmail(string recipient, string content)
    {
        var htmlContent = $"<html><body><h1>Contoso Luxury Dinner Recipe</h1><br/>{content}</body></html>";
        try
        {
            var emailSendOperation = await _emailClient.SendAsync(
                wait: WaitUntil.Completed,
                senderAddress: _sender,
                recipientAddress: recipient,
                subject: Subject,
                htmlContent: htmlContent);
            Log.Information("Email sent to '{Recipient}' with operation id {OperationId}", 
                recipient, emailSendOperation.Id);
        }
        catch (RequestFailedException ex)
        {
            Log.Error(ex, "Email send operation failed with error code: {ErrorCode}, message: {Message}",
                ex.ErrorCode, ex.Message);
            return false;
        }

        return true;
    }
}