-- =====================================================
-- 015 CRM ENGINE (CLEAN CUSTOMER RELATIONSHIP DOMAIN)
-- NO EXECUTION / NO RUNTIME STATE / NO PLATFORM LOGIC
-- =====================================================
--
-- SSOT: contacts, companies, leads, pipelines, opportunities,
-- tasks, interactions, notes, tags, lists, campaigns, custom fields.
--
-- References only: tenants, profiles (002/000), customer tenants via FK.
-- Does NOT own: orders, subscriptions, payments, bookings, devices,
-- portal, onboarding, support cases (006).
-- Campaign SSOT: crm_campaigns (marketing acquisition) only.
-- In-product upsells → 013.upsell_campaigns. Plan upsells → 009.upsell_rules.
-- CRM domain enums SSOT: 001_core_types_rev19.sql (section 14).
-- =====================================================

-- =====================================================
-- 1. PIPELINES
-- =====================================================

create table if not exists crm_pipelines (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    name text not null,

    description text,

    is_default boolean not null default false,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz
);

create index if not exists idx_crm_pipelines_tenant_created
on crm_pipelines (tenant_id, created_at desc);

create unique index if not exists uq_crm_pipelines_default_per_tenant
on crm_pipelines (tenant_id)
where is_default = true and deleted_at is null;

create trigger trg_crm_pipelines_updated_at
before update on crm_pipelines
for each row execute function platform.set_updated_at();

comment on table public.crm_pipelines is
    'Generic sales pipeline definitions (Sales, Partners, Enterprise, Upsell, etc.).';

-- =====================================================
-- 2. PIPELINE STAGES
-- =====================================================

create table if not exists crm_pipeline_stages (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    pipeline_id uuid not null references crm_pipelines(id) on delete cascade,

    name text not null,

    stage_order int not null,

    probability numeric(5,2) not null default 0,

    is_terminal boolean not null default false,

    terminal_outcome crm_terminal_outcome,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz,

    unique (pipeline_id, stage_order),

    constraint chk_crm_pipeline_stages_order check (stage_order > 0),

    constraint chk_crm_pipeline_stages_probability check (
        probability >= 0 and probability <= 100
    ),

    constraint chk_crm_pipeline_stages_terminal_outcome check (
        (not is_terminal and terminal_outcome is null)
        or (is_terminal and terminal_outcome is not null)
    )
);

create index if not exists idx_crm_pipeline_stages_pipeline
on crm_pipeline_stages (pipeline_id);

create index if not exists idx_crm_pipeline_stages_tenant_created
on crm_pipeline_stages (tenant_id, created_at desc);

create trigger trg_crm_pipeline_stages_updated_at
before update on crm_pipeline_stages
for each row execute function platform.set_updated_at();

-- =====================================================
-- 3. CAMPAIGNS
-- =====================================================

create table if not exists crm_campaigns (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    name text not null,

    description text,

    campaign_type crm_campaign_type not null default 'other',

    status crm_campaign_status not null default 'draft',

    start_date date,

    end_date date,

    budget numeric(12,2),

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz,

    constraint chk_crm_campaigns_date_range check (
        start_date is null
        or end_date is null
        or end_date >= start_date
    ),

    constraint chk_crm_campaigns_budget check (
        budget is null or budget >= 0
    )
);

create index if not exists idx_crm_campaigns_tenant_created
on crm_campaigns (tenant_id, created_at desc);

create index if not exists idx_crm_campaigns_tenant_status
on crm_campaigns (tenant_id, status)
where deleted_at is null;

create trigger trg_crm_campaigns_updated_at
before update on crm_campaigns
for each row execute function platform.set_updated_at();

comment on table public.crm_campaigns is
    'Marketing campaign definitions. Owns no contacts; relationships via leads and list membership.';

-- =====================================================
-- 4. TAGS
-- =====================================================

create table if not exists crm_tags (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    name text not null,

    color text,

    created_at timestamptz not null default now(),

    deleted_at timestamptz
);

create index if not exists idx_crm_tags_tenant_created
on crm_tags (tenant_id, created_at desc);

create unique index if not exists uq_crm_tags_tenant_name
on crm_tags (tenant_id, lower(name))
where deleted_at is null;

-- =====================================================
-- 5. COMPANIES
-- =====================================================

create table if not exists crm_companies (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    name text not null,

    legal_name text,

    website text,

    industry text,

    owner_user_id uuid references platform.profiles(id) on delete set null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz
);

create index if not exists idx_crm_companies_tenant_created
on crm_companies (tenant_id, created_at desc);

create index if not exists idx_crm_companies_owner
on crm_companies (tenant_id, owner_user_id)
where owner_user_id is not null and deleted_at is null;

create trigger trg_crm_companies_updated_at
before update on crm_companies
for each row execute function platform.set_updated_at();

comment on table public.crm_companies is
    'CRM company records. Customer tenant links via crm_company_tenants (M:N).';

-- =====================================================
-- 6. CONTACTS
-- =====================================================

create table if not exists crm_contacts (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    first_name text,

    last_name text,

    display_name text,

    email text,

    phone text,

    language text default 'en',

    timezone text,

    marketing_consent boolean not null default false,

    marketing_consent_at timestamptz,

    gdpr_consent boolean not null default false,

    gdpr_consent_at timestamptz,

    status crm_contact_status not null default 'active',

    lead_source text,

    owner_user_id uuid references platform.profiles(id) on delete set null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz,

    constraint chk_crm_contacts_has_identity check (
        display_name is not null
        or first_name is not null
        or last_name is not null
        or email is not null
    ),

    constraint chk_crm_contacts_marketing_consent_at check (
        (not marketing_consent and marketing_consent_at is null)
        or marketing_consent
    ),

    constraint chk_crm_contacts_gdpr_consent_at check (
        (not gdpr_consent and gdpr_consent_at is null)
        or gdpr_consent
    )
);

create index if not exists idx_crm_contacts_tenant_created
on crm_contacts (tenant_id, created_at desc);

create index if not exists idx_crm_contacts_tenant_email
on crm_contacts (tenant_id, lower(email))
where email is not null and deleted_at is null;

create index if not exists idx_crm_contacts_owner
on crm_contacts (tenant_id, owner_user_id)
where owner_user_id is not null and deleted_at is null;

create trigger trg_crm_contacts_updated_at
before update on crm_contacts
for each row execute function platform.set_updated_at();

comment on table public.crm_contacts is
    'CRM contact SSOT. Free-text notes live in crm_notes; no duplicated tenant data.';

-- =====================================================
-- 7. LEADS
-- =====================================================

create table if not exists crm_leads (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    first_name text,

    last_name text,

    email text,

    phone text,

    status crm_lead_status not null default 'new',

    source text,

    score numeric(5,2),

    temperature crm_lead_temperature,

    owner_user_id uuid references platform.profiles(id) on delete set null,

    estimated_value numeric(12,2),

    campaign_id uuid references crm_campaigns(id) on delete set null,

    converted_contact_id uuid references crm_contacts(id) on delete set null,

    converted_company_id uuid references crm_companies(id) on delete set null,

    converted_tenant_id uuid,

    converted_at timestamptz,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz,

    constraint chk_crm_leads_score check (
        score is null or (score >= 0 and score <= 100)
    ),

    constraint chk_crm_leads_estimated_value check (
        estimated_value is null or estimated_value >= 0
    ),

    constraint chk_crm_leads_converted_state check (
        (status <> 'converted' and converted_at is null)
        or (status = 'converted' and converted_at is not null)
    )
);

create index if not exists idx_crm_leads_tenant_created
on crm_leads (tenant_id, created_at desc);

create index if not exists idx_crm_leads_tenant_status
on crm_leads (tenant_id, status)
where deleted_at is null;

create index if not exists idx_crm_leads_campaign
on crm_leads (campaign_id)
where campaign_id is not null;

create index if not exists idx_crm_leads_converted_tenant
on crm_leads (converted_tenant_id)
where converted_tenant_id is not null;

create trigger trg_crm_leads_updated_at
before update on crm_leads
for each row execute function platform.set_updated_at();

comment on table public.crm_leads is
    'Prospect leads. May convert to contact, company, and/or customer tenant. CRM does not create tenants.';

comment on column public.crm_leads.converted_tenant_id is
    'Reference to 002 tenants after conversion. Set by application layer; CRM stores FK only.';

-- =====================================================
-- 8. CONTACT ↔ COMPANY (M:N WITH ROLES)
-- =====================================================

create table if not exists crm_contact_company (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    contact_id uuid not null references crm_contacts(id) on delete cascade,

    company_id uuid not null references crm_companies(id) on delete cascade,

    role text not null,

    is_primary boolean not null default false,

    created_at timestamptz not null default now(),

    deleted_at timestamptz,

    unique (contact_id, company_id, role)
);

create index if not exists idx_crm_contact_company_contact
on crm_contact_company (contact_id)
where deleted_at is null;

create index if not exists idx_crm_contact_company_company
on crm_contact_company (company_id)
where deleted_at is null;

create index if not exists idx_crm_contact_company_tenant_created
on crm_contact_company (tenant_id, created_at desc);

create unique index if not exists uq_crm_contact_company_primary
on crm_contact_company (contact_id, company_id)
where is_primary = true and deleted_at is null;

-- =====================================================
-- 9. COMPANY ↔ TENANT (M:N — REQUIRED FOR NORMALIZATION)
-- =====================================================

create table if not exists crm_company_tenants (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    company_id uuid not null references crm_companies(id) on delete cascade,

    linked_tenant_id uuid,

    relationship_type text,

    created_at timestamptz not null default now(),

    deleted_at timestamptz,

    unique (company_id, linked_tenant_id)
);

create index if not exists idx_crm_company_tenants_company
on crm_company_tenants (company_id)
where deleted_at is null and linked_tenant_id is not null;

create index if not exists idx_crm_company_tenants_linked_tenant
on crm_company_tenants (linked_tenant_id)
where deleted_at is null;

create index if not exists idx_crm_company_tenants_tenant_created
on crm_company_tenants (tenant_id, created_at desc);

comment on table public.crm_company_tenants is
    'Links CRM companies to customer tenants (002). Required M:N; not duplicated on crm_companies.';

-- =====================================================
-- 10. CONTACT ↔ TENANT (M:N — REQUIRED FOR NORMALIZATION)
-- =====================================================

create table if not exists crm_contact_tenants (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    contact_id uuid not null references crm_contacts(id) on delete cascade,

    linked_tenant_id uuid,

    relationship_type text,

    created_at timestamptz not null default now(),

    deleted_at timestamptz,

    unique (contact_id, linked_tenant_id)
);

create index if not exists idx_crm_contact_tenants_contact
on crm_contact_tenants (contact_id)
where deleted_at is null and linked_tenant_id is not null;

create index if not exists idx_crm_contact_tenants_linked_tenant
on crm_contact_tenants (linked_tenant_id)
where deleted_at is null;

create index if not exists idx_crm_contact_tenants_tenant_created
on crm_contact_tenants (tenant_id, created_at desc);

comment on table public.crm_contact_tenants is
    'Links CRM contacts to customer tenants (002) they manage. Required M:N.';

-- =====================================================
-- 11. OPPORTUNITIES
-- =====================================================

create table if not exists crm_opportunities (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    pipeline_id uuid not null references crm_pipelines(id) on delete restrict,

    stage_id uuid not null references crm_pipeline_stages(id) on delete restrict,

    contact_id uuid references crm_contacts(id) on delete set null,

    company_id uuid references crm_companies(id) on delete set null,

    linked_tenant_id uuid,

    name text not null,

    expected_revenue numeric(12,2),

    probability numeric(5,2),

    expected_close_date date,

    owner_user_id uuid references platform.profiles(id) on delete set null,

    status crm_opportunity_status not null default 'open',

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz,

    constraint chk_crm_opportunities_probability check (
        probability is null or (probability >= 0 and probability <= 100)
    ),

    constraint chk_crm_opportunities_expected_revenue check (
        expected_revenue is null or expected_revenue >= 0
    ),

    constraint chk_crm_opportunities_has_party check (
        contact_id is not null
        or company_id is not null
        or linked_tenant_id is not null
    )
);

create index if not exists idx_crm_opportunities_tenant_created
on crm_opportunities (tenant_id, created_at desc);

create index if not exists idx_crm_opportunities_pipeline_stage
on crm_opportunities (pipeline_id, stage_id)
where deleted_at is null;

create index if not exists idx_crm_opportunities_owner
on crm_opportunities (tenant_id, owner_user_id)
where owner_user_id is not null and deleted_at is null;

create index if not exists idx_crm_opportunities_linked_tenant
on crm_opportunities (linked_tenant_id)
where linked_tenant_id is not null;

create trigger trg_crm_opportunities_updated_at
before update on crm_opportunities
for each row execute function platform.set_updated_at();

comment on column public.crm_opportunities.linked_tenant_id is
    'Optional reference to 002 customer tenant associated with this deal.';

-- =====================================================
-- 12. TASKS
-- =====================================================

create table if not exists crm_tasks (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    title text not null,

    description text,

    target_type crm_task_target_type not null,

    target_id uuid not null,

    priority priority_level not null default 'normal',

    due_at timestamptz,

    status crm_task_status not null default 'pending',

    owner_user_id uuid references platform.profiles(id) on delete set null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz
);

create index if not exists idx_crm_tasks_tenant_created
on crm_tasks (tenant_id, created_at desc);

create index if not exists idx_crm_tasks_target
on crm_tasks (tenant_id, target_type, target_id)
where deleted_at is null;

create index if not exists idx_crm_tasks_owner_due
on crm_tasks (tenant_id, owner_user_id, due_at)
where deleted_at is null and status in ('pending', 'in_progress');

create trigger trg_crm_tasks_updated_at
before update on crm_tasks
for each row execute function platform.set_updated_at();

comment on table public.crm_tasks is
    'Follow-up tasks bound to exactly one CRM or customer tenant target.';

-- =====================================================
-- 13. INTERACTIONS (APPEND-ONLY)
-- =====================================================

create table if not exists crm_interactions (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    interaction_type crm_interaction_type not null,

    subject text,

    metadata jsonb not null default '{}'::jsonb,

    contact_id uuid references crm_contacts(id) on delete set null,

    company_id uuid references crm_companies(id) on delete set null,

    lead_id uuid references crm_leads(id) on delete set null,

    opportunity_id uuid references crm_opportunities(id) on delete set null,

    recorded_by uuid references platform.profiles(id) on delete set null,

    occurred_at timestamptz not null default now(),

    created_at timestamptz not null default now(),

    deleted_at timestamptz,

    constraint chk_crm_interactions_has_context check (
        contact_id is not null
        or company_id is not null
        or lead_id is not null
        or opportunity_id is not null
    )
);

create index if not exists idx_crm_interactions_tenant_created
on crm_interactions (tenant_id, created_at desc);

create index if not exists idx_crm_interactions_contact
on crm_interactions (contact_id, occurred_at desc)
where contact_id is not null;

create index if not exists idx_crm_interactions_lead
on crm_interactions (lead_id, occurred_at desc)
where lead_id is not null;

create index if not exists idx_crm_interactions_opportunity
on crm_interactions (opportunity_id, occurred_at desc)
where opportunity_id is not null;

comment on table public.crm_interactions is
    'Immutable interaction history. Metadata only — no email bodies. Append-only; soft-delete via deleted_at.';

-- =====================================================
-- 14. NOTES
-- =====================================================

create table if not exists crm_notes (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    entity_type crm_entity_type not null,

    entity_id uuid not null,

    body text not null,

    version int not null default 1,

    author_user_id uuid references platform.profiles(id) on delete set null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz,

    constraint chk_crm_notes_version check (version > 0)
);

create index if not exists idx_crm_notes_tenant_created
on crm_notes (tenant_id, created_at desc);

create index if not exists idx_crm_notes_entity
on crm_notes (tenant_id, entity_type, entity_id, created_at desc)
where deleted_at is null;

create trigger trg_crm_notes_updated_at
before update on crm_notes
for each row execute function platform.set_updated_at();

comment on column public.crm_notes.version is
    'Increment on edit for versioning-ready note history at application layer.';

-- =====================================================
-- 15. TAG ASSIGNMENTS
-- =====================================================

create table if not exists crm_tag_assignments (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    tag_id uuid not null references crm_tags(id) on delete cascade,

    entity_type crm_entity_type not null,

    entity_id uuid not null,

    created_at timestamptz not null default now(),

    deleted_at timestamptz,

    unique (tag_id, entity_type, entity_id)
);

create index if not exists idx_crm_tag_assignments_entity
on crm_tag_assignments (tenant_id, entity_type, entity_id)
where deleted_at is null;

create index if not exists idx_crm_tag_assignments_tenant_created
on crm_tag_assignments (tenant_id, created_at desc);

-- =====================================================
-- 16. LISTS
-- =====================================================

create table if not exists crm_lists (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    name text not null,

    description text,

    list_type crm_list_type not null default 'static',

    filter_config jsonb,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz,

    constraint chk_crm_lists_dynamic_filter check (
        list_type <> 'dynamic' or filter_config is not null
    )
);

create index if not exists idx_crm_lists_tenant_created
on crm_lists (tenant_id, created_at desc);

create unique index if not exists uq_crm_lists_tenant_name
on crm_lists (tenant_id, lower(name))
where deleted_at is null;

create trigger trg_crm_lists_updated_at
before update on crm_lists
for each row execute function platform.set_updated_at();

-- =====================================================
-- 17. LIST MEMBERS
-- =====================================================

create table if not exists crm_list_members (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    list_id uuid not null references crm_lists(id) on delete cascade,

    contact_id uuid not null references crm_contacts(id) on delete cascade,

    added_at timestamptz not null default now(),

    deleted_at timestamptz,

    unique (list_id, contact_id)
);

create index if not exists idx_crm_list_members_list
on crm_list_members (list_id)
where deleted_at is null;

create index if not exists idx_crm_list_members_contact
on crm_list_members (contact_id)
where deleted_at is null;

create index if not exists idx_crm_list_members_tenant_created
on crm_list_members (tenant_id, added_at desc);

-- =====================================================
-- 18. CUSTOM FIELDS
-- =====================================================

create table if not exists crm_custom_fields (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    field_key text not null,

    label text not null,

    field_type crm_custom_field_type not null,

    applies_to crm_entity_type not null,

    options jsonb,

    is_required boolean not null default false,

    display_order int not null default 0,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz,

    unique (tenant_id, field_key, applies_to),

    constraint chk_crm_custom_fields_options check (
        field_type not in ('select', 'multiselect') or options is not null
    )
);

create index if not exists idx_crm_custom_fields_tenant_created
on crm_custom_fields (tenant_id, created_at desc);

create index if not exists idx_crm_custom_fields_applies_to
on crm_custom_fields (tenant_id, applies_to)
where deleted_at is null;

create trigger trg_crm_custom_fields_updated_at
before update on crm_custom_fields
for each row execute function platform.set_updated_at();

-- =====================================================
-- 19. CUSTOM FIELD VALUES
-- =====================================================

create table if not exists crm_custom_field_values (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    custom_field_id uuid not null references crm_custom_fields(id) on delete cascade,

    entity_type crm_entity_type not null,

    entity_id uuid not null,

    value_text text,

    value_number numeric,

    value_boolean boolean,

    value_date date,

    value_datetime timestamptz,

    value_json jsonb,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    unique (custom_field_id, entity_id),

    constraint chk_crm_custom_field_values_has_value check (
        value_text is not null
        or value_number is not null
        or value_boolean is not null
        or value_date is not null
        or value_datetime is not null
        or value_json is not null
    )
);

create index if not exists idx_crm_custom_field_values_entity
on crm_custom_field_values (tenant_id, entity_type, entity_id);

create index if not exists idx_crm_custom_field_values_tenant_created
on crm_custom_field_values (tenant_id, created_at desc);

create trigger trg_crm_custom_field_values_updated_at
before update on crm_custom_field_values
for each row execute function platform.set_updated_at();

-- =====================================================
-- 20. TENANT FKs (DEFERRED PATTERN)
-- =====================================================

do $$
begin
    alter table public.crm_pipelines
        add constraint fk_crm_pipelines_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_pipeline_stages
        add constraint fk_crm_pipeline_stages_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_campaigns
        add constraint fk_crm_campaigns_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_tags
        add constraint fk_crm_tags_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_companies
        add constraint fk_crm_companies_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_contacts
        add constraint fk_crm_contacts_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_leads
        add constraint fk_crm_leads_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_leads
        add constraint fk_crm_leads_converted_tenant
        foreign key (converted_tenant_id) references public.tenants(id) on delete set null;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_contact_company
        add constraint fk_crm_contact_company_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_company_tenants
        add constraint fk_crm_company_tenants_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_company_tenants
        add constraint fk_crm_company_tenants_linked_tenant
        foreign key (linked_tenant_id) references public.tenants(id) on delete set null;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_contact_tenants
        add constraint fk_crm_contact_tenants_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_contact_tenants
        add constraint fk_crm_contact_tenants_linked_tenant
        foreign key (linked_tenant_id) references public.tenants(id) on delete set null;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_opportunities
        add constraint fk_crm_opportunities_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_opportunities
        add constraint fk_crm_opportunities_linked_tenant
        foreign key (linked_tenant_id) references public.tenants(id) on delete set null;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_tasks
        add constraint fk_crm_tasks_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_interactions
        add constraint fk_crm_interactions_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_notes
        add constraint fk_crm_notes_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_tag_assignments
        add constraint fk_crm_tag_assignments_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_lists
        add constraint fk_crm_lists_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_list_members
        add constraint fk_crm_list_members_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_custom_fields
        add constraint fk_crm_custom_fields_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.crm_custom_field_values
        add constraint fk_crm_custom_field_values_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

-- =====================================================
-- 21. INTEGRITY TRIGGERS
-- =====================================================

create or replace function public.enforce_crm_owner_membership()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.owner_user_id is null then
        return new;
    end if;

    if not exists (
        select 1
        from public.tenant_memberships tm
        where tm.tenant_id = new.tenant_id
          and tm.user_id = new.owner_user_id
          and tm.is_active = true
    ) then
        raise exception 'owner_user_id must be an active member of tenant_id';
    end if;

    return new;
end;
$$;

create trigger trg_crm_contacts_owner_membership
before insert or update on public.crm_contacts
for each row execute function public.enforce_crm_owner_membership();

create trigger trg_crm_companies_owner_membership
before insert or update on public.crm_companies
for each row execute function public.enforce_crm_owner_membership();

create trigger trg_crm_leads_owner_membership
before insert or update on public.crm_leads
for each row execute function public.enforce_crm_owner_membership();

create trigger trg_crm_opportunities_owner_membership
before insert or update on public.crm_opportunities
for each row execute function public.enforce_crm_owner_membership();

create trigger trg_crm_tasks_owner_membership
before insert or update on public.crm_tasks
for each row execute function public.enforce_crm_owner_membership();

create or replace function public.enforce_crm_pipeline_stage_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_stage_pipeline uuid;
    v_stage_tenant uuid;
    v_pipeline_tenant uuid;
begin
    select ps.pipeline_id, ps.tenant_id
    into v_stage_pipeline, v_stage_tenant
    from public.crm_pipeline_stages ps
    where ps.id = new.stage_id;

    if not found then
        raise exception 'pipeline stage not found';
    end if;

    if v_stage_pipeline <> new.pipeline_id then
        raise exception 'opportunity stage must belong to the selected pipeline';
    end if;

    select p.tenant_id
    into v_pipeline_tenant
    from public.crm_pipelines p
    where p.id = new.pipeline_id;

    if v_stage_tenant <> new.tenant_id or v_pipeline_tenant <> new.tenant_id then
        raise exception 'pipeline, stage, and opportunity tenant_id must match';
    end if;

    return new;
end;
$$;

create trigger trg_crm_opportunities_pipeline_stage_scope
before insert or update on public.crm_opportunities
for each row execute function public.enforce_crm_pipeline_stage_scope();

create or replace function public.enforce_crm_child_tenant_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_parent_tenant uuid;
begin
    if tg_table_name = 'crm_pipeline_stages' then
        select p.tenant_id into v_parent_tenant
        from public.crm_pipelines p
        where p.id = new.pipeline_id;
    elsif tg_table_name = 'crm_contact_company' then
        select c.tenant_id into v_parent_tenant
        from public.crm_contacts c
        where c.id = new.contact_id;

        if v_parent_tenant is distinct from (
            select co.tenant_id from public.crm_companies co where co.id = new.company_id
        ) then
            raise exception 'contact and company must belong to the same tenant';
        end if;
    elsif tg_table_name = 'crm_company_tenants' then
        select c.tenant_id into v_parent_tenant
        from public.crm_companies c
        where c.id = new.company_id;
    elsif tg_table_name = 'crm_contact_tenants' then
        select c.tenant_id into v_parent_tenant
        from public.crm_contacts c
        where c.id = new.contact_id;
    elsif tg_table_name = 'crm_list_members' then
        select l.tenant_id into v_parent_tenant
        from public.crm_lists l
        where l.id = new.list_id;

        if v_parent_tenant is distinct from (
            select ct.tenant_id from public.crm_contacts ct where ct.id = new.contact_id
        ) then
            raise exception 'list and contact must belong to the same tenant';
        end if;
    elsif tg_table_name = 'crm_tag_assignments' then
        select t.tenant_id into v_parent_tenant
        from public.crm_tags t
        where t.id = new.tag_id;
    elsif tg_table_name = 'crm_custom_field_values' then
        select cf.tenant_id into v_parent_tenant
        from public.crm_custom_fields cf
        where cf.id = new.custom_field_id;

        if new.entity_type <> (
            select cf.applies_to from public.crm_custom_fields cf where cf.id = new.custom_field_id
        ) then
            raise exception 'custom field value entity_type must match field applies_to';
        end if;
    else
        return new;
    end if;

    if not found then
        raise exception 'parent record not found';
    end if;

    if v_parent_tenant <> new.tenant_id then
        raise exception 'tenant_id must match parent record tenant_id';
    end if;

    return new;
end;
$$;

create trigger trg_crm_pipeline_stages_tenant_consistency
before insert or update on public.crm_pipeline_stages
for each row execute function public.enforce_crm_child_tenant_consistency();

create trigger trg_crm_contact_company_tenant_consistency
before insert or update on public.crm_contact_company
for each row execute function public.enforce_crm_child_tenant_consistency();

create trigger trg_crm_company_tenants_tenant_consistency
before insert or update on public.crm_company_tenants
for each row execute function public.enforce_crm_child_tenant_consistency();

create trigger trg_crm_contact_tenants_tenant_consistency
before insert or update on public.crm_contact_tenants
for each row execute function public.enforce_crm_child_tenant_consistency();

create trigger trg_crm_list_members_tenant_consistency
before insert or update on public.crm_list_members
for each row execute function public.enforce_crm_child_tenant_consistency();

create trigger trg_crm_tag_assignments_tenant_consistency
before insert or update on public.crm_tag_assignments
for each row execute function public.enforce_crm_child_tenant_consistency();

create trigger trg_crm_custom_field_values_tenant_consistency
before insert or update on public.crm_custom_field_values
for each row execute function public.enforce_crm_child_tenant_consistency();

create or replace function public.enforce_crm_lead_campaign_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_campaign_tenant uuid;
begin
    if new.campaign_id is null then
        return new;
    end if;

    select c.tenant_id
    into v_campaign_tenant
    from public.crm_campaigns c
    where c.id = new.campaign_id;

    if not found then
        raise exception 'campaign not found';
    end if;

    if v_campaign_tenant <> new.tenant_id then
        raise exception 'lead campaign must belong to the same tenant';
    end if;

    return new;
end;
$$;

create trigger trg_crm_leads_campaign_scope
before insert or update on public.crm_leads
for each row execute function public.enforce_crm_lead_campaign_scope();

create or replace function public.enforce_crm_lead_conversion_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_contact_tenant uuid;
    v_company_tenant uuid;
begin
    if new.converted_contact_id is not null then
        select c.tenant_id into v_contact_tenant
        from public.crm_contacts c
        where c.id = new.converted_contact_id;

        if v_contact_tenant <> new.tenant_id then
            raise exception 'converted contact must belong to the same tenant';
        end if;
    end if;

    if new.converted_company_id is not null then
        select c.tenant_id into v_company_tenant
        from public.crm_companies c
        where c.id = new.converted_company_id;

        if v_company_tenant <> new.tenant_id then
            raise exception 'converted company must belong to the same tenant';
        end if;
    end if;

    return new;
end;
$$;

create trigger trg_crm_leads_conversion_scope
before insert or update on public.crm_leads
for each row execute function public.enforce_crm_lead_conversion_scope();

create or replace function public.enforce_crm_opportunity_party_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_contact_tenant uuid;
    v_company_tenant uuid;
begin
    if new.contact_id is not null then
        select c.tenant_id into v_contact_tenant
        from public.crm_contacts c
        where c.id = new.contact_id;

        if v_contact_tenant <> new.tenant_id then
            raise exception 'opportunity contact must belong to the same tenant';
        end if;
    end if;

    if new.company_id is not null then
        select c.tenant_id into v_company_tenant
        from public.crm_companies c
        where c.id = new.company_id;

        if v_company_tenant <> new.tenant_id then
            raise exception 'opportunity company must belong to the same tenant';
        end if;
    end if;

    return new;
end;
$$;

create trigger trg_crm_opportunities_party_scope
before insert or update on public.crm_opportunities
for each row execute function public.enforce_crm_opportunity_party_scope();

create or replace function public.enforce_crm_interaction_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_entity_tenant uuid;
begin
    if new.contact_id is not null then
        select c.tenant_id into v_entity_tenant from public.crm_contacts c where c.id = new.contact_id;
        if v_entity_tenant <> new.tenant_id then
            raise exception 'interaction contact tenant mismatch';
        end if;
    end if;

    if new.company_id is not null then
        select c.tenant_id into v_entity_tenant from public.crm_companies c where c.id = new.company_id;
        if v_entity_tenant <> new.tenant_id then
            raise exception 'interaction company tenant mismatch';
        end if;
    end if;

    if new.lead_id is not null then
        select l.tenant_id into v_entity_tenant from public.crm_leads l where l.id = new.lead_id;
        if v_entity_tenant <> new.tenant_id then
            raise exception 'interaction lead tenant mismatch';
        end if;
    end if;

    if new.opportunity_id is not null then
        select o.tenant_id into v_entity_tenant from public.crm_opportunities o where o.id = new.opportunity_id;
        if v_entity_tenant <> new.tenant_id then
            raise exception 'interaction opportunity tenant mismatch';
        end if;
    end if;

    return new;
end;
$$;

create trigger trg_crm_interactions_scope
before insert on public.crm_interactions
for each row execute function public.enforce_crm_interaction_scope();

create or replace function public.enforce_crm_interaction_immutability()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'DELETE' then
        raise exception 'crm_interactions cannot be hard-deleted; set deleted_at instead';
    end if;

    if new.tenant_id is distinct from old.tenant_id
       or new.interaction_type is distinct from old.interaction_type
       or new.subject is distinct from old.subject
       or new.metadata is distinct from old.metadata
       or new.contact_id is distinct from old.contact_id
       or new.company_id is distinct from old.company_id
       or new.lead_id is distinct from old.lead_id
       or new.opportunity_id is distinct from old.opportunity_id
       or new.recorded_by is distinct from old.recorded_by
       or new.occurred_at is distinct from old.occurred_at
       or new.created_at is distinct from old.created_at then
        raise exception 'crm_interactions are append-only; only deleted_at may change';
    end if;

    return new;
end;
$$;

create trigger trg_crm_interactions_immutability
before update or delete on public.crm_interactions
for each row execute function public.enforce_crm_interaction_immutability();

create or replace function public.enforce_crm_task_target()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_target_tenant uuid;
    v_found boolean := false;
begin
    case new.target_type
        when 'lead' then
            select l.tenant_id, true into v_target_tenant, v_found
            from public.crm_leads l where l.id = new.target_id;
        when 'opportunity' then
            select o.tenant_id, true into v_target_tenant, v_found
            from public.crm_opportunities o where o.id = new.target_id;
        when 'contact' then
            select c.tenant_id, true into v_target_tenant, v_found
            from public.crm_contacts c where c.id = new.target_id;
        when 'company' then
            select c.tenant_id, true into v_target_tenant, v_found
            from public.crm_companies c where c.id = new.target_id;
        when 'tenant' then
            select t.id, true into v_target_tenant, v_found
            from public.tenants t where t.id = new.target_id;
    end case;

    if not coalesce(v_found, false) then
        raise exception 'task target not found for type %', new.target_type;
    end if;

    if new.target_type = 'tenant' then
        if new.tenant_id <> new.target_id then
            raise exception 'task with target_type=tenant must reference the same tenant_id';
        end if;
    elsif v_target_tenant <> new.tenant_id then
        raise exception 'task target must belong to the same tenant';
    end if;

    return new;
end;
$$;

create trigger trg_crm_tasks_target
before insert or update on public.crm_tasks
for each row execute function public.enforce_crm_task_target();

create or replace function public.enforce_crm_note_entity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_entity_tenant uuid;
    v_found boolean := false;
begin
    case new.entity_type
        when 'lead' then
            select l.tenant_id, true into v_entity_tenant, v_found
            from public.crm_leads l where l.id = new.entity_id;
        when 'opportunity' then
            select o.tenant_id, true into v_entity_tenant, v_found
            from public.crm_opportunities o where o.id = new.entity_id;
        when 'contact' then
            select c.tenant_id, true into v_entity_tenant, v_found
            from public.crm_contacts c where c.id = new.entity_id;
        when 'company' then
            select c.tenant_id, true into v_entity_tenant, v_found
            from public.crm_companies c where c.id = new.entity_id;
        when 'tenant' then
            select t.id, true into v_entity_tenant, v_found
            from public.tenants t where t.id = new.entity_id;
    end case;

    if not coalesce(v_found, false) then
        raise exception 'note entity not found for type %', new.entity_type;
    end if;

    if new.entity_type = 'tenant' then
        if new.tenant_id <> new.entity_id then
            raise exception 'note on tenant must use matching tenant_id';
        end if;
    elsif v_entity_tenant <> new.tenant_id then
        raise exception 'note entity must belong to the same tenant';
    end if;

    return new;
end;
$$;

create trigger trg_crm_notes_entity
before insert or update on public.crm_notes
for each row execute function public.enforce_crm_note_entity();

create or replace function public.enforce_crm_tag_assignment_entity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_entity_tenant uuid;
    v_found boolean := false;
begin
    case new.entity_type
        when 'lead' then
            select l.tenant_id, true into v_entity_tenant, v_found
            from public.crm_leads l where l.id = new.entity_id;
        when 'opportunity' then
            select o.tenant_id, true into v_entity_tenant, v_found
            from public.crm_opportunities o where o.id = new.entity_id;
        when 'contact' then
            select c.tenant_id, true into v_entity_tenant, v_found
            from public.crm_contacts c where c.id = new.entity_id;
        when 'company' then
            select c.tenant_id, true into v_entity_tenant, v_found
            from public.crm_companies c where c.id = new.entity_id;
        when 'tenant' then
            select t.id, true into v_entity_tenant, v_found
            from public.tenants t where t.id = new.entity_id;
    end case;

    if not coalesce(v_found, false) then
        raise exception 'tag assignment entity not found for type %', new.entity_type;
    end if;

    if new.entity_type = 'tenant' then
        if new.tenant_id <> new.entity_id then
            raise exception 'tag on tenant must use matching tenant_id';
        end if;
    elsif v_entity_tenant <> new.tenant_id then
        raise exception 'tagged entity must belong to the same tenant';
    end if;

    return new;
end;
$$;

create trigger trg_crm_tag_assignments_entity
before insert or update on public.crm_tag_assignments
for each row execute function public.enforce_crm_tag_assignment_entity();

create or replace function public.enforce_crm_custom_field_value_shape()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_field_type public.crm_custom_field_type;
begin
    select cf.field_type
    into v_field_type
    from public.crm_custom_fields cf
    where cf.id = new.custom_field_id;

    if not found then
        raise exception 'custom field not found';
    end if;

    case v_field_type
        when 'text' then
            if new.value_text is null
               or new.value_number is not null
               or new.value_boolean is not null
               or new.value_date is not null
               or new.value_datetime is not null
               or new.value_json is not null then
                raise exception 'invalid value columns for text custom field';
            end if;
        when 'number' then
            if new.value_number is null
               or new.value_text is not null
               or new.value_boolean is not null
               or new.value_date is not null
               or new.value_datetime is not null
               or new.value_json is not null then
                raise exception 'invalid value columns for number custom field';
            end if;
        when 'boolean' then
            if new.value_boolean is null
               or new.value_text is not null
               or new.value_number is not null
               or new.value_date is not null
               or new.value_datetime is not null
               or new.value_json is not null then
                raise exception 'invalid value columns for boolean custom field';
            end if;
        when 'date' then
            if new.value_date is null
               or new.value_text is not null
               or new.value_number is not null
               or new.value_boolean is not null
               or new.value_datetime is not null
               or new.value_json is not null then
                raise exception 'invalid value columns for date custom field';
            end if;
        when 'datetime' then
            if new.value_datetime is null
               or new.value_text is not null
               or new.value_number is not null
               or new.value_boolean is not null
               or new.value_date is not null
               or new.value_json is not null then
                raise exception 'invalid value columns for datetime custom field';
            end if;
        when 'select' then
            if new.value_text is null
               or new.value_number is not null
               or new.value_boolean is not null
               or new.value_date is not null
               or new.value_datetime is not null
               or new.value_json is not null then
                raise exception 'invalid value columns for select custom field';
            end if;
        when 'multiselect' then
            if new.value_json is null
               or new.value_text is not null
               or new.value_number is not null
               or new.value_boolean is not null
               or new.value_date is not null
               or new.value_datetime is not null then
                raise exception 'invalid value columns for multiselect custom field';
            end if;
    end case;

    return new;
end;
$$;

create trigger trg_crm_custom_field_values_shape
before insert or update on public.crm_custom_field_values
for each row execute function public.enforce_crm_custom_field_value_shape();

-- =====================================================
-- 22. RLS (EXPLICIT TENANT POLICIES — REQUIRED AFTER 014)
-- =====================================================

do $$
declare
    v_table text;
begin
    foreach v_table in array array[
        'crm_pipelines',
        'crm_pipeline_stages',
        'crm_campaigns',
        'crm_tags',
        'crm_companies',
        'crm_contacts',
        'crm_leads',
        'crm_contact_company',
        'crm_company_tenants',
        'crm_contact_tenants',
        'crm_opportunities',
        'crm_tasks',
        'crm_interactions',
        'crm_notes',
        'crm_tag_assignments',
        'crm_lists',
        'crm_list_members',
        'crm_custom_fields',
        'crm_custom_field_values'
    ] loop
        execute format('alter table public.%I enable row level security', v_table);
        execute format('drop policy if exists %1$s_select on public.%1$I', v_table);
        execute format('drop policy if exists %1$s_insert on public.%1$I', v_table);
        execute format('drop policy if exists %1$s_update on public.%1$I', v_table);
        execute format('drop policy if exists %1$s_delete on public.%1$I', v_table);
        execute format(
            'create policy %1$s_select on public.%1$I for select to authenticated using (platform.is_platform_admin() or public.has_tenant_access(tenant_id))',
            v_table
        );
        execute format(
            'create policy %1$s_insert on public.%1$I for insert to authenticated with check (platform.is_platform_admin() or (public.has_tenant_access(tenant_id) and (platform.is_admin() or platform.has_role(''manager''))))',
            v_table
        );
        execute format(
            'create policy %1$s_update on public.%1$I for update to authenticated using (platform.is_platform_admin() or (public.has_tenant_access(tenant_id) and (platform.is_admin() or platform.has_role(''manager'')))) with check (platform.is_platform_admin() or (public.has_tenant_access(tenant_id) and (platform.is_admin() or platform.has_role(''manager''))))',
            v_table
        );
        execute format(
            'create policy %1$s_delete on public.%1$I for delete to authenticated using (platform.is_platform_admin() or (public.has_tenant_access(tenant_id) and (platform.is_admin() or platform.has_role(''manager''))))',
            v_table
        );
        execute format('alter table public.%I force row level security', v_table);
    end loop;
end $$;

-- =====================================================
-- END 015 CRM ENGINE
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('015_crm_engine_rev19', 'REV19.CRM', false)
on conflict (version) do nothing;
