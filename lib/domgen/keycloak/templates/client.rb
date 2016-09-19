require 'securerandom'

def generate(client)
  data = {
    'id' => SecureRandom.uuid.to_s,
    'clientId' => client.key,
    "name" => client.name,
    'rootUrl' => client.root_url,
    'baseUrl' => client.base_url,
    'surrogateAuthRequired' => client.surrogate_auth_required?,
    'enabled' => true,
    'clientAuthenticatorType' => 'client-secret',
    'redirectUris' => client.redirect_uris,
    'webOrigins' => [],
    'notBefore' => 0,
    'bearerOnly' => client.bearer_only?,
    'consentRequired' => client.consent_required?,
    'standardFlowEnabled' => client.standard_flow?,
    'implicitFlowEnabled' => client.implicit_flow?,
    'directAccessGrantsEnabled' => client.direct_access_grants?,
    'serviceAccountsEnabled' => client.service_accounts?,
    'publicClient' => client.public_client?,
    'frontchannelLogout' => client.frontchannel_logout?,
    'protocol' => 'openid-connect',
    'attributes' => {
      'saml.assertion.signature' => 'false',
      'saml.force.post.binding' => 'false',
      'saml.multivalued.roles' => 'false',
      'saml.encrypt' => 'false',
      'saml_force_name_id_format' => 'false',
      'saml.client.signature' => 'false',
      'saml.authnstatement' => 'false',
      'saml.server.signature' => 'false'
    },
    'fullScopeAllowed' => client.full_scope_allowed?,
    'nodeReRegistrationTimeout' => -1,
    'protocolMappers' => [
    ],
    'useTemplateConfig' => false,
    'useTemplateScope' => false,
    'useTemplateMappers' => false
  }

  ::JSON.pretty_generate(data)
end
