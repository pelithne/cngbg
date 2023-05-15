using System.Diagnostics.Metrics;

namespace DinnerApi.Modules.DinnerMeals;

internal static class DinnerMetrics
{
    public static string Name => "DinnerApi.Dinner";
    public static Meter Meter { get; } = new Meter(Name);
    
    public static Counter<long> DinnerMealsProposedTotal { get; } = Meter.CreateCounter<long>("dinner_meals_proposed_total", "Total number of dinner meals proposed");
}