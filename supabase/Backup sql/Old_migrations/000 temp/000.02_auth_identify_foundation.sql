-- =====================================================
-- REV19 SUPABASE PLATFORM LAYER
-- PART 2 - FINAL IMPROVED IDENTITY FOUNDATION
-- =====================================================

-- =====================================================
-- 000.02 PROFILES (PURE IDENTITY LAYER ONLY)
-- =====================================================

create table if not exists platform.profiles (
    id uuid primary key references auth.users(id) on delete cascade,

    email text,
    full_name text,
    avatar_url text,

    is_active boolean default true,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_email
on platform.profiles (email);

create trigger trg_profiles_updated_at
before update on platform.profiles
for each row execute function platform.set_updated_at();

-- =====================================================
-- 000.02.01 AUTH USER HOOK (SAFE + SUPABASE CORRECT)
-- =====================================================

create or replace function platform.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = platform, public
as $$
begin
    insert into platform.profiles (id, email, full_name)
    values (
        new.id,
        new.email,
        coalesce(new.raw_user_meta_data->>'full_name', '')
    )
    on conflict (id) do nothing;

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function platform.handle_new_auth_user();

-- =====================================================
-- 000.02.02 IDENTITY LAYER (ONLY ACCESS POINT FOR 001–013)
-- =====================================================

create or replace function platform.current_user_id()
returns uuid
language sql
stable
as $$
    select auth.uid();
$$;

create or replace function platform.current_user_email()
returns text
language sql
stable
as $$
    select coalesce(auth.jwt() ->> 'email', auth.email());
$$;

-- =====================================================
-- 000.02.03 AUTH STATE HELPERS
-- =====================================================

create or replace function platform.is_authenticated()
returns boolean
language sql
stable
as $$
    select auth.uid() is not null;
$$;

-- =====================================================
-- 000.02.04 PLATFORM ADMIN (REMOVED FROM PROFILE LOGIC)
-- =====================================================

-- NOTE:
-- Admin is NOT stored on profile anymore.
-- This will be handled via roles system in PART 3.

create or replace function platform.is_platform_admin()
returns boolean
language sql
stable
as $$
    select exists (
        select 1
        from platform.profiles p
        where p.id = auth.uid()
        and p.email ilike '%@your-platform-domain.com'
    );
$$;

-- =====================================================
-- 000.02.05 IDENTITY CONTEXT OBJECT (RLS READY)
-- =====================================================

create or replace function platform.get_identity()
returns jsonb
language sql
stable
as $$
    select jsonb_build_object(
        'user_id', auth.uid(),
        'email', coalesce(auth.jwt() ->> 'email', auth.email()),
        'is_authenticated', auth.uid() is not null
    );
$$;

-- =====================================================
-- 000.02.06 TENANT HOOK (PLACEHOLDER FOR PART 3)
-- =====================================================

create or replace function platform.current_tenant_id()
returns uuid
language sql
stable
as $$
    select null::uuid;
$$;

comment on function platform.current_tenant_id is '
Reserved for PART 3 - Multi-tenant authorization layer.
Must be implemented before any RLS policies in domain layer.
';

-- =====================================================
-- 000.02.07 ARCHITECTURE GUARANTEES
-- =====================================================

comment on table platform.profiles is '
REV19 RULE:
- This table represents ONLY global identity
- NO roles
- NO tenant logic
- NO permissions
- Authorization is handled in PART 3+
';

-- =====================================================
-- END PART 2 (FINAL IMPROVED)
-- =====================================================