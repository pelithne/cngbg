using DinnerApi.Configuration;
using DinnerApi.Modules.DinnerMeals;
using DinnerApi.Modules.Recipes;
using Serilog;

const string appName = "dinner-api";

var builder = WebApplication.CreateBuilder(args);

builder.ConfigureTelemetry(appName);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddDaprClient();
builder.Services.AddHealthChecks();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHealthChecks("/healthz");
app.UseSerilogRequestLogging();

app.MapRecipes();
app.MapDinnerMeals();

app.Run();