using Azure.Core;
using Azure.Identity;
using Classon.Identity;

var app = WebApplication.CreateBuilder(args).Build();

TokenCredential tokenCredential = app.Configuration.GetSection("CACHE_ACCESS_TOKEN").Get<bool>()
    ? CachingTokenCredential.Create(new AzureCliCredential())
    : new AzureCliCredential();

// With inspiration of https://github.com/gsoft-inc/azure-cli-credentials-proxy/blob/main/Program.cs
app.MapGet("/token", async (string resource) =>
{
    var token = await tokenCredential.GetTokenAsync(
        new TokenRequestContext(new[] { resource }), CancellationToken.None);
    if (app.Configuration.GetSection("DEBUG_ACCESS_TOKEN").Get<bool>())
        Console.WriteLine($"Received token for {resource}: {token.Token}");
    return new Dictionary<string, object>
    {
        ["access_token"] = token.Token,
        ["expires_on"] = token.ExpiresOn.ToUnixTimeSeconds(),
        ["token_type"] = "Bearer"
    };
});

app.Run();
