select
    proname,
    prosrc
from pg_proc
where prosrc ilike '%RAISE%';