using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Serilog;
using Serilog.Sinks.OpenTelemetry;
using Serilog.Sinks.SystemConsole.Themes;

namespace AiProcessor.Configuration;

public static class ObservabilityConfiguration
{
    public static void ConfigureTelemetry(this WebApplicationBuilder builder, string appName)
    {
        builder.Host.UseSerilog((context, configuration) =>
        {
            var serilogConfiguration = configuration
                .ReadFrom.Configuration(context.Configuration)
                .Enrich.FromLogContext();

            if (context.HostingEnvironment.IsDevelopment() || builder.Configuration["USE_CONSOLE_LOG_OUTPUT"] == "true")
                serilogConfiguration.WriteTo.Console(theme: AnsiConsoleTheme.Sixteen);

            var otlpEndpoint = context.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"];
            if (!string.IsNullOrEmpty(otlpEndpoint))
            {
                var protocol = context.Configuration["OTEL_EXPORTER_OTLP_PROTOCOL"] == "http/protobuf"
                    ? OtlpProtocol.HttpProtobuf
                    : OtlpProtocol.GrpcProtobuf;
                serilogConfiguration.WriteTo.OpenTelemetry(options =>
                {
                    options.Protocol = protocol;
                    options.Endpoint = $"{otlpEndpoint}/v1/logs";
                    options.ResourceAttributes = new Dictionary<string, object>()
                    {
                        ["service.name"] = appName,
                    };
                });
            }
        });

        var resourceBuilder = ResourceBuilder.CreateDefault().AddService(serviceName: appName, serviceVersion: "0.1");
        
        builder.Services.AddOpenTelemetry()
            .WithTracing(tracingBuilder =>
            {
                tracingBuilder
                    .AddOtlpExporter()
                    .SetResourceBuilder(resourceBuilder)
                    .AddHttpClientInstrumentation()
                    .AddGrpcClientInstrumentation()
                    .AddAspNetCoreInstrumentation();
            })
            .WithMetrics(metricsBuilder =>
            {
                metricsBuilder
                    .AddOtlpExporter()
                    .SetResourceBuilder(resourceBuilder)
                    .AddHttpClientInstrumentation()
                    .AddAspNetCoreInstrumentation();
            });
    }
}