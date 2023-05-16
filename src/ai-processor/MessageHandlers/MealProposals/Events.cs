namespace AiProcessor.MessageHandlers.MealProposals;

public record ProposedDinnerMealRequestEvent(string RecipeId, string MainComponent, string? Email, string Type);

public record RecipeNotificationEvent(string RecipeId, string MainComponent, string Email, string Recipe)
{
    public string Type => nameof(RecipeNotificationEvent);
}
