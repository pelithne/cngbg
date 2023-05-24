using Dapr.Client;

namespace WebFrontend.Data;

public class RecipesListService
{
    private readonly DaprClient _daprClient;

    public RecipesListService(DaprClient daprClient)
    {
        _daprClient = daprClient;
    }
    
    public async Task<List<RecipeResponse>> GetRecipes()
    {
        return await _daprClient.InvokeMethodAsync<List<RecipeResponse>>(HttpMethod.Get, "dinner-api", "v1/recipes");
    }
}

public record RecipeResponse(string RecipeId, string MainComponent, string Recipe);