using System.ComponentModel;
using System.Text.RegularExpressions;
using Microsoft.SemanticKernel.SkillDefinition;

namespace AiProcessor.MessageHandlers.MealProposals.Skills;

public sealed class TemperatureConverterSkill
{
    private static readonly Regex FahrenheitRegex = new(@"(\d+)?°([Ff])", RegexOptions.Compiled);

    [SKFunction, Description("Converts temperatures from Fahrenheit to Celsius in a text")]
    public string ConvertToCelsius([Description("Text to find all tempertures")] string input)
    {
        var output = input;
        var matches = FahrenheitRegex.Matches(output);

        foreach (Match match in matches)
        {
            var fahrenheit = match.Groups[1].Value;
            var cleaned = fahrenheit.Replace("°F", "");
            var celsius = (int)((int.Parse(cleaned) - 32) / 1.8);
            output = output.Replace(match.Value, $"{celsius}°C");
        }

        return output;
    }
    
    
    [SKFunction, Description("Appends Celsius temperatures to Fahrenheit in a text")]
    public string AppendCelsius([Description("Text to find all tempertures")] string input)
    {
        var output = input;
        var matches = FahrenheitRegex.Matches(output);

        foreach (Match match in matches)
        {
            var fahrenheit = match.Groups[1].Value;
            var cleaned = fahrenheit.Replace("°F", "");
            var celsius = (int)((int.Parse(cleaned) - 32) / 1.8);
            output = output.Replace(match.Value, $"{cleaned}°F ({celsius}°C)");
        }

        return output;
    }
}