using Dapr.Client;

namespace DinnerApi.Modules.DinnerMeals;

public static class DinnerApi
{
    public static void MapDinnerMeals(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("v1/dinner-meals");

        group.MapPost("propose", ProposeMeal);
    }

    private static async Task<IResult> ProposeMeal(ProposeDinnerMealRequest request, DaprClient client)
    {
        if (string.IsNullOrEmpty(request.MainComponent))
            return TypedResults.BadRequest("MainComponent is required");
        
        var recipeId = Guid.NewGuid().ToString();
        var proposedDinnerMealRequestEvent = new ProposedDinnerMealRequestEvent(recipeId, request.MainComponent, request.Email);

        await client.PublishEventAsync("pubsub", "dinner-meals-requests", proposedDinnerMealRequestEvent);
        
        DinnerMetrics.DinnerMealsProposedTotal.Add(1);
        
        return TypedResults.Accepted($"v1/recipes/{recipeId}", new
        {
            RecipeId = recipeId
        });
    }
}