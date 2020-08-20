require 'securerandom'

def generate(client)
  data = {
    'id' => SecureRandom.uuid.to_s,
    'clientId' => client.client_id,
    'name' => client.name,
    'rootUrl' => client.root_url,
    'baseUrl' => client.base_url,
    'adminUrl' => client.admin_url,
    'surrogateAuthRequired' => client.surrogate_auth_required?,
    'enabled' => true,
    'clientAuthenticatorType' => 'client-secret',
    'redirectUris' => client.redirect_uris,
    'webOrigins' => client.web_origins,
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
    'attributes' => {},
    'fullScopeAllowed' => client.full_scope_allowed?,
    'nodeReRegistrationTimeout' => -1,
    'protocolMappers' => [
    ],
    'useTemplateConfig' => false,
    'useTemplateScope' => false,
    'useTemplateMappers' => false
  }

  if client.public_client?
    data['attributes'].merge!(
      'saml.assertion.signature' => 'false',
      'saml.force.post.binding' => 'false',
      'saml.multivalued.roles' => 'false',
      'saml.encrypt' => 'false',
      'saml_force_name_id_format' => 'false',
      'saml.client.signature' => 'false',
      'saml.authnstatement' => 'false',
      'saml.server.signature' => 'false'
    )
  else
    data['secret'] = client.secret
  end

  if client.keycloak_repository.keycloak_version == '11'
    data['alwaysDisplayInConsole'] = client.always_display_in_console?
    data['defaultRoles'] = client.default_roles
  end

  unless client.bearer_only?
    # Bearer only clients do not return any claims as they do not generate token. Thus it makes no sense
    # to configure any as it is the responsibility of the client that generates the token to populate the
    # token with the right claims.

    client.claims.each do |claim|
      claim_data = {
        'id' => SecureRandom.uuid.to_s,
        'name' => claim.name,
        'protocol' => claim.protocol,
        'protocolMapper' => claim.protocol_mapper,
        'consentRequired' => claim.consent_required?,
        'config' => claim.config.dup
      }
      claim_data['consentText'] = claim.consent_text if claim.consent_text
      data['protocolMappers'] << claim_data
    end
  end

  data.dup.each_pair do |k, v|
    data.delete(k) if v == ''
  end

  ::JSON.pretty_generate(data)
end
