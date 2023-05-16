using EmailSender.Configuration;
using EmailSender.MessageHandlers.RecipesNotifications;

const string appName = "email-sender";

var builder = WebApplication.CreateBuilder(args);

builder.ConfigureTelemetry(appName);

builder.Services.AddDaprClient();
builder.Services.AddHealthChecks();
builder.Services.AddSingleton<RecipeEmailSender>();

var app = builder.Build();

app.UseHealthChecks("/healthz");

app.MapSubscribeHandler();
app.UseCloudEvents();
app.MapRecipesNotificationHandler();

app.Run();