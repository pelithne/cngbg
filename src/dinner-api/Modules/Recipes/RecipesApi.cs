namespace DinnerApi.Modules.Recipes;

public static class RecipesApi
{
    public static void MapRecipes(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("v1/recipes");

        group.MapGet("{id}", GetRecipe);
    }

    private static async Task<IResult> GetRecipe(string id)
    {
        return TypedResults.NotFound();
    }
}