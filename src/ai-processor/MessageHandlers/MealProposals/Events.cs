namespace AiProcessor.MessageHandlers.MealProposals;

public record ProposedDinnerMealRequestEvent(string RecipeId, string MainComponent, string? Email, string Type);
