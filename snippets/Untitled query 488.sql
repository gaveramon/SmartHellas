select
    grantee,
    privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = 'integration_oauth_configs'
order by grantee, privilege_type;