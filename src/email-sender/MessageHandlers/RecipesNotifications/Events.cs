namespace EmailSender.MessageHandlers.RecipesNotifications;

public record RecipeNotificationEvent(string RecipeId, string MainComponent, string Email, string Recipe, string Type);
