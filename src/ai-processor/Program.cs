using AiProcessor.Configuration;
using AiProcessor.MessageHandlers.MealProposals;

const string appName = "ai-processor";

var builder = WebApplication.CreateBuilder(args);

builder.ConfigureTelemetry(appName);

builder.Services.AddDaprClient();
builder.Services.AddHealthChecks();
builder.Services.AddSingleton<IMealProposalProcessor, OpenAIProcessor>();

var app = builder.Build();

app.UseHealthChecks("/healthz");

app.MapSubscribeHandler();
app.UseCloudEvents();
app.MapMealProposalHandler();

app.Run();