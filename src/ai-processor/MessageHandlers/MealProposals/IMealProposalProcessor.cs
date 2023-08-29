namespace AiProcessor.MessageHandlers.MealProposals;

public interface IMealProposalProcessor
{
    Task<string> GenerateRecipe(string mainComponent);
}