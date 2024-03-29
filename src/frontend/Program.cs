using WebFrontend.Configuration;
using WebFrontend.Data;

var builder = WebApplication.CreateBuilder(args);

builder.ConfigureTelemetry("web-frontend");

// Add services to the container.
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();
builder.Services.AddDaprClient();
builder.Services.AddScoped<RecipeProposalService>();
builder.Services.AddScoped<RecipesListService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();

app.MapSubscribeHandler();

app.MapBlazorHub();
app.MapFallbackToPage("/_Host");

app.Run();
