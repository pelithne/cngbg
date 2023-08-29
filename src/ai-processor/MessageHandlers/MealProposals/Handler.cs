using Dapr;
using Dapr.Client;
using Microsoft.AspNetCore.Mvc;
using Serilog;

namespace AiProcessor.MessageHandlers.MealProposals;

public static class MealProposalHandler
{
    public static void MapMealProposalHandler(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("meal-proposals");

        group.MapPost("event-handler", Handler);
    }

    [Topic("requests", "dinner-meal-requests")]
    private static async Task<IResult> Handler(ProposedDinnerMealRequestEvent mealRequestEvent, [FromServices]IMealProposalProcessor processor, [FromServices]DaprClient daprClient)
    {
        var recipe = await processor.GenerateRecipe(mealRequestEvent.MainComponent);
        
        await daprClient.SaveStateAsync("recipes", mealRequestEvent.RecipeId, 
            new GeneratedRecipe(mealRequestEvent.RecipeId, mealRequestEvent.MainComponent, recipe));
        
        Log.Information("Recipe generated with id: {RecipeId}", mealRequestEvent.RecipeId);
        
        if (mealRequestEvent.Email != null)
            await daprClient.PublishEventAsync("notifications", "recipe-notifications", new RecipeNotificationEvent(mealRequestEvent.RecipeId, mealRequestEvent.MainComponent, mealRequestEvent.Email, recipe));
        
        return TypedResults.Ok();
    }
}