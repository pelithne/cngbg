using System.Text.Json;
using Dapr.Client;
using Microsoft.AspNetCore.Mvc;

namespace DinnerApi.Modules.Recipes;

public static class RecipesApi
{
    public static void MapRecipes(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("v1/recipes");

        group.MapGet("", GetRecipes);
        group.MapGet("{id}", GetRecipe);
    }

    private static async Task<IResult> GetRecipe(string id, [FromServices] DaprClient client)
    {
        var recipe = await client.GetStateAsync<GeneratedRecipe>("recipes", id);
        if (recipe == null)
            return TypedResults.NotFound();

        return TypedResults.Ok(new RecipeResponse(recipe.RecipeId, recipe.MainComponent, recipe.Recipe));
    }

    private static async Task<IResult> GetRecipes([FromServices] DaprClient client)
    {
        var query = JsonSerializer.Serialize(new
        {
            page = new
            {
                limit = 10
            }
        });
        var queryResponse = await client.QueryStateAsync<GeneratedRecipe>("recipes", query);
        return TypedResults.Ok(queryResponse.Results.Select(x =>
            new RecipeResponse(x.Data.RecipeId, x.Data.MainComponent, x.Data.Recipe)));
    }
}