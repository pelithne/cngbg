using Dapr.Client;
using Microsoft.AspNetCore.Mvc;

namespace DinnerApi.Modules.Recipes;

public static class RecipesApi
{
    public static void MapRecipes(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("v1/recipes");

        group.MapGet("{id}", GetRecipe);
    }

    private static async Task<IResult> GetRecipe(string id, [FromServices] DaprClient client)
    {
        var recipe = await client.GetStateAsync<GeneratedRecipe>("recipes", id);
        if (recipe == null)
            return TypedResults.NotFound();

        return TypedResults.Ok(new RecipeResponse(recipe.RecipeId, recipe.Recipe));
    }
}