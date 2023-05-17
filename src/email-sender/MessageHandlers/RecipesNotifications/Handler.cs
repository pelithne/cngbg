using Dapr;
using Dapr.Client;
using Microsoft.AspNetCore.Mvc;
using Serilog;

namespace EmailSender.MessageHandlers.RecipesNotifications;

public static class RecipesNotificationsHandler
{
    public static void MapRecipesNotificationHandler(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("recipe-notifications");

        group.MapPost("event-handler", Handler);
    }

    [Topic("notifications", "recipe-notifications")]
    private static async Task<IResult> Handler(RecipeNotificationEvent recipeNotificationEvent, [FromServices]RecipeEmailSender recipeEmailSender)
    {
        var result = await recipeEmailSender.SendEmail(recipeNotificationEvent.Email, recipeNotificationEvent.Recipe);
        return result ? TypedResults.Ok() : TypedResults.Conflict();
    }
}