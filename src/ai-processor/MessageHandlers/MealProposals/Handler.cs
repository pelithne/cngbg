using Dapr;
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

    [Topic("pubsub", "dinner-meals-requests")]
    private static async Task<IResult> Handler(ProposedDinnerMealRequestEvent mealRequestEvent, [FromServices]MealProposalProcessor processor)
    {
        var recipe = await processor.Process(mealRequestEvent.MainComponent);
        Log.Information(recipe);
        return TypedResults.Ok();
    }
}