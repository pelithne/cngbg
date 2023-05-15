namespace DinnerApi.Modules.DinnerMeals;

public record ProposedDinnerMealRequestEvent(string RecipeId, string MainComponent, string? Email)
{    
    public string Type => nameof(ProposedDinnerMealRequestEvent);
}
