using Azure;
using Azure.AI.OpenAI;
using Serilog;

namespace AiProcessor.MessageHandlers.MealProposals;

public class MealProposalProcessor
{
    private readonly OpenAIClient _client;
    private readonly string _model;

    public MealProposalProcessor(IConfiguration configuration)
    {
        _model = configuration["AZURE_OPENAI_API_MODEL"];
        _client = new OpenAIClient(
            new Uri(configuration["AZURE_OPENAI_API_ENDPOINT"]),
            new AzureKeyCredential(configuration["AZURE_OPENAI_API_KEY"]));
    }
    
    public async Task<string> GenerateRecipe(string mainComponent)
    {
        var response = await _client.GetChatCompletionsAsync(_model, new ChatCompletionsOptions
        {
            Messages =
            {
                new ChatMessage(ChatRole.System, System),
                new ChatMessage(ChatRole.User, Example1Q),
                new ChatMessage(ChatRole.Assistant, Example1QA),
                new ChatMessage(ChatRole.User, mainComponent)
            },
            Temperature = 0.7f,
            MaxTokens = 1000,
            NucleusSamplingFactor = 0.95f,
            FrequencyPenalty = 0,
            PresencePenalty = 0,
        });

        var responseValue = response.Value;
        
        Log.Information("Recipe generated. Total Token usage: {TotalTokens}, Prompt Token usage: {PromptTokens}, Completion tokens: {CompletionTokens} ", 
            responseValue.Usage.TotalTokens, responseValue.Usage.PromptTokens, responseValue.Usage.CompletionTokens);

        var message = responseValue.Choices.First().Message.Content;

        return message;
    }
    
    private const string System =
        "You are an AI assistant that helps people find recipes for luxury dinners based one piece of protein component in the dish. " +
        "You will suggest one luxury full recipe. The user should supply the main component for the dish. " +
        "Always respond in HTML format and without any images.";

    private const string Example1Q = "Beef";
    private const string Example1QA = 
        "Here is a luxurious beef recipe you can try: \n" + 
        "<h3>Beef Wellington</h3> <p>This classic dish is a showstopper and perfect for a special occasion.</p> " +
        "<h4>Ingredients:</h4> <ul> <li>2 lbs beef tenderloin</li> <li>1 lb puff pastry</li> " +
        "<li>1 cup mushroom duxelle (finely chopped mushrooms, shallots, and herbs)</li> " +
        "<li>2 tbsp Dijon mustard</li> <li>2 egg yolks</li> <li>1 tbsp water</li> <li>Salt and pepper</li> " +
        "</ul> <h4>Instructions:</h4> <ol> <li>Preheat oven to 425°F.</li> <li>Sear the beef tenderloin on all sides in a hot skillet.</li> " +
        "<li>Season the beef with salt and pepper and brush with Dijon mustard.</li> " +
        "<li>Roll out the puff pastry and spread the mushroom duxelle on it.</li> " +
        "<li>Place the beef on top of the mushroom duxelle and wrap the pastry around it, sealing the edges.</li> " +
        "<li>Brush the egg wash over the top and sides of the pastry and bake for 35-40 minutes or until the pastry is golden brown.</li> " +
        "<li>Let rest for 10 minutes before slicing.</li> </ol> " +
        "<p>Serve with roasted vegetables and a red wine sauce for a truly indulgent meal.</p>";
}