using AiProcessor.MessageHandlers.MealProposals.Skills;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.Orchestration;

namespace AiProcessor.MessageHandlers.MealProposals;

public class SemanticKernelProcessor : IMealProposalProcessor
{
    private const string JsonConfigSkillsDirectory = "MessageHandlers/MealProposals/JsonConfigSkills";
    
    private readonly KernelBuilder _kernelBuilder;
    
    public SemanticKernelProcessor(ILoggerFactory loggerFactory, IConfiguration configuration)
    {
        _kernelBuilder = new KernelBuilder()
            .WithLogger(loggerFactory.CreateLogger("Kernel"))
            .WithAzureTextCompletionService(
                configuration["AZURE_OPENAI_API_MODEL"],
                configuration["AZURE_OPENAI_API_ENDPOINT"],
                configuration["AZURE_OPENAI_API_KEY"]
            );
    }
    
    public async Task<string> GenerateRecipe(string mainComponent)
    {
        var kernel = _kernelBuilder.Build();
        var variables = new ContextVariables(mainComponent);
        variables.Set("language", "swedish");
        var recipes = kernel.ImportSemanticSkillFromDirectory(JsonConfigSkillsDirectory, "RecipeSkill");
        var writer = kernel.ImportSemanticSkillFromDirectory(JsonConfigSkillsDirectory, "WriterSkill");
        var temperatureConverter = kernel.ImportSkill(new TemperatureConverterSkill());
        var poundsToKilograms = kernel.ImportSkill(new PoundsConverterSkill());

        var result = await kernel.RunAsync(
            variables,
            recipes["Generate2"],
            temperatureConverter["AppendCelsius"],
            poundsToKilograms["ConvertToKilograms"]
            //writer["Translate"]
        );

        return result.Result;
    }
}