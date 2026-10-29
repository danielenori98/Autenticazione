namespace Autenticazione.Models
{
    public class RichiestaLogin
    {
        public string Username { get; set; } = string.Empty;

        public string Password { get; set; } = string.Empty;

        public string Modalita { get; set; } = string.Empty;
    }
}
