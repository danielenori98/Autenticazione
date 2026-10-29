using Autenticazione.Models;
using System.DirectoryServices.Protocols;
using System.Net;

namespace Autenticazione.Services
{
    public class ServizioLDAP
    {
        private readonly IConfiguration configuration;

        public ServizioLDAP(IConfiguration configuration)
        {
            this.configuration = configuration;
        }

        public async Task<bool> Login(RichiestaLogin richiesta)
        {
            string server = this.configuration.GetValue<string>("OpzioniLDAP:Server") ?? "localhost";
            int porta = this.configuration.GetValue<int?>("OpzioniLDAP:Porta") ?? 389;
            LdapDirectoryIdentifier identifier = new LdapDirectoryIdentifier(server, porta);

            return await Task.Run(() =>
            {
                using (LdapConnection connection = new LdapConnection(identifier))
                {
                    connection.SessionOptions.SecureSocketLayer = false;
                    connection.SessionOptions.ProtocolVersion = 3;
                    connection.AuthType = AuthType.Basic;

                    string distinguishedName = $"uid={richiesta.Username},ou=users,dc=example,dc=com";

                    try
                    {
                        if (string.IsNullOrWhiteSpace(richiesta.Username))
                        {
                            return false;
                        }

                        connection.Bind(new NetworkCredential(distinguishedName, richiesta.Password));
                        return true;
                    }
                    catch (LdapException)
                    {
                        return false;
                    }
                }
            }
            );
        }
    }
}