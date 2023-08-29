using System.ComponentModel;
using System.Text.RegularExpressions;
using Microsoft.SemanticKernel.SkillDefinition;

namespace AiProcessor.MessageHandlers.MealProposals.Skills;

public sealed class PoundsConverterSkill
{
    private static readonly Regex FahrenheitRegex = new(@"(\d+)? lb[(s)]?", RegexOptions.Compiled);

    [SKFunction, Description("Converts pounds to kilograms")]
    public string ConvertToKilograms([Description("Text to find all tempertures")] string input)
    {
        var output = input;
        var matches = FahrenheitRegex.Matches(output);

        foreach (Match match in matches)
        {
            var fahrenheit = match.Groups[1].Value;
            var cleaned = fahrenheit.Replace("lbs", "");
            var kilogram = (decimal)(int.Parse(cleaned) * 0.45359237);
            if (kilogram < 1m)
            {
                var gram = Math.Floor(kilogram * 1000m);
                output = output.Replace(match.Value, $"{gram} gram");
            }
            else
            {
                output = output.Replace(match.Value, $"{kilogram:F2} kg");
            }
        }

        return output;
    }
}