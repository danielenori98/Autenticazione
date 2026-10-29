using Autenticazione.Models;

namespace Autenticazione.Services
{
    public class ServizioKeycloak
    {
        private readonly IConfiguration configuration;

        public ServizioKeycloak(IConfiguration configuration)
        {
            this.configuration = configuration;
        }
        
        public async Task<bool> Login(RichiestaLogin richiesta)
        {
            string url = this.configuration.GetValue<string>("OpzioniKeycloak:Url") ?? "http://localhost:8080";
            string realm = this.configuration.GetValue<string>("OpzioniKeycloak:Realm") ?? "myrealm";
            string clientId = this.configuration.GetValue<string>("OpzioniKeycloak:ClientId") ?? "myclient";
            string clientSecret = this.configuration.GetValue<string>("OpzioniKeycloak:ClientSecret") ?? "mysecret";
            using (HttpClient httpClient = new HttpClient())
            {
                var requestData = new Dictionary<string, string>
                {
                    { "grant_type", "password" },
                    { "client_id", clientId },
                    { "client_secret", clientSecret },
                    { "username", richiesta.Username },
                    { "password", richiesta.Password }
                };
                var requestContent = new FormUrlEncodedContent(requestData);
                var response = await httpClient.PostAsync($"{url}/realms/{realm}/protocol/openid-connect/token", requestContent);
                return response.IsSuccessStatusCode;
            }
        }
    }
}
