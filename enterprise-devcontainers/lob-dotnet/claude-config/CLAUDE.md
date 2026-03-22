# LOB: .NET Platform

## Stack
- .NET 10 with C# 14
- Clean Architecture (hexagonal ports-and-adapters)
- CQRS via MediatR, EF Core, MassTransit
- Blazor/MudBlazor for UI components
- xUnit + FluentAssertions + Moq for testing
- NetArchTest for architecture enforcement

## Conventions
- Use `dotnet format` before committing
- All public APIs must have XML doc comments
- Repository pattern with IUnitOfWork
- Domain events via MediatR notifications
- Use record types for DTOs and value objects
- Nullable reference types enabled project-wide
