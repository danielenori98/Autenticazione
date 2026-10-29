using Autenticazione.Models;
using Autenticazione.Services;
using Microsoft.AspNetCore.Mvc;

namespace Autenticazione.Controllers
{
    [Route("api/Autenticazione")]
    [ApiController]
    public class ControllerAutenticazione : ControllerBase
    {
        private readonly ServizioLDAP servizioLdap;
        private readonly ServizioKeycloak servizioKeycloak;


        public ControllerAutenticazione(ServizioLDAP servizioLdap, ServizioKeycloak servizioKeycloak)
        {
            this.servizioLdap = servizioLdap;
            this.servizioKeycloak = servizioKeycloak;
        }

        [HttpPost]
        public async Task<IActionResult> Autenticazione([FromBody] RichiestaLogin richiesta)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            if (richiesta.Modalita == "LDAP")
            {
                bool successo = await this.servizioLdap.Login(richiesta);

                if (!successo)
                {
                    return Unauthorized(new { messaggio = "Nome utente o password non validi." });
                }

                return Ok(new { messaggio = "Accesso Effettuato" });
            }
            else if (richiesta.Modalita == "Keycloak")
            {
                bool successo = await this.servizioKeycloak.Login(richiesta);
                if (!successo)
                {
                    return Unauthorized(new { messaggio = "Nome utente o password non validi." });
                }
                return Ok(new { messaggio = "Accesso Effettuato" });
            }
            else
            {
                return BadRequest(new { messaggio = "Modalità di autenticazione non valida." });
            }
        }
    }
}