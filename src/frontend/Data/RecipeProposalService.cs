using System.ComponentModel.DataAnnotations;
using Dapr.Client;

namespace WebFrontend.Data;

public class RecipeRequest
{
    [Required]
    public string MainComponent { get; set; }
}

public class RecipeProposalService
{
    private readonly DaprClient _daprClient;

    public RecipeProposalService(DaprClient daprClient)
    {
        _daprClient = daprClient;
    }
    
    public async Task PostRecipeRequest(RecipeRequest request)
    {
        await _daprClient.InvokeMethodAsync(HttpMethod.Post, "dinner-api", "v1/dinner-meals/propose",
            new DinnerProposalRequest(request.MainComponent, null));
    }
}

public record DinnerProposalRequest(string MainComponent, string? Email);
