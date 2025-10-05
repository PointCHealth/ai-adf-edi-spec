namespace HealthcareEDI.InboundRouter.Services;

public interface IRoutingService
{
    Task<Models.RoutingResult> RouteFileAsync(Models.RoutingContext context);
}
