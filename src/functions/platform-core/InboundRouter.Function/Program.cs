using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.ApplicationInsights.Extensibility;
using HealthcareEDI.InboundRouter.Services;

var host = new HostBuilder()
    .ConfigureFunctionsWebApplication()
    .ConfigureAppConfiguration((context, config) =>
    {
        // Add Azure Key Vault configuration
        var builtConfig = config.Build();
        var keyVaultEndpoint = builtConfig["KeyVaultEndpoint"];
        
        if (!string.IsNullOrEmpty(keyVaultEndpoint))
        {
            config.AddAzureKeyVault(new Uri(keyVaultEndpoint), new Azure.Identity.DefaultAzureCredential());
        }
    })
    .ConfigureServices((context, services) =>
    {
        // Application Insights
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();

        // Configure options
        services.Configure<Configuration.RoutingOptions>(
            context.Configuration.GetSection("RoutingOptions"));

        // Register services
        services.AddScoped<IRoutingService, RoutingService>();
        
        // Azure SDK clients
        services.AddSingleton(sp =>
        {
            var connectionString = context.Configuration["StorageAccountConnectionString"];
            return new Azure.Storage.Blobs.BlobServiceClient(connectionString);
        });
        
        services.AddSingleton(sp =>
        {
            var connectionString = context.Configuration["ServiceBusConnectionString"];
            return new Azure.Messaging.ServiceBus.ServiceBusClient(connectionString);
        });

        // Logging
        services.AddLogging();
    })
    .Build();

host.Run();
