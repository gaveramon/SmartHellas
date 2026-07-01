export interface CustomerProposalRow {
  id: string;
  tenant_id: string;
  property_id: string | null;
  status: string;
  total_estimated_value: number | null;
  presented_at: string | null;
  accepted_at: string | null;
  expires_at: string | null;
  source_campaign_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface ProposalItemRow {
  id: string;
  tenant_id: string;
  proposal_id: string;
  item_type: string;
  plan_id: string | null;
  monetization_package_id: string | null;
  reference_id: string | null;
  quantity: number;
  price_estimate: number | null;
  created_at: string;
}

export interface ProposalDetail {
  proposal: CustomerProposalRow;
  items: ProposalItemRow[];
}

export interface MonetizationPackageRow {
  id: string;
  name: string;
  description: string | null;
  package_type: string;
  device_bundle_id: string | null;
  base_price: number | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface UpsellCampaignRow {
  id: string;
  tenant_id: string | null;
  trigger_event: string | null;
  target_package_id: string | null;
  campaign_rules: Record<string, unknown> | null;
  is_active: boolean;
  created_at: string;
}

export interface ServiceActivationStateRow {
  id: string;
  tenant_id: string;
  property_id: string | null;
  service_type: string;
  status: string;
  source_proposal_id: string | null;
  source_subscription_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface ConversionEventRow {
  id: string;
  tenant_id: string;
  property_id: string | null;
  proposal_id: string | null;
  event_type: string;
  source: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface ConversionScoreRow {
  id: string;
  tenant_id: string;
  property_id: string | null;
  score: number | null;
  factors: Record<string, unknown> | null;
  calculated_at: string;
}

export interface CreateProposalRequest {
  property_id?: string;
  total_estimated_value?: number;
  expires_at?: string;
  source_campaign_id?: string;
}

export interface UpdateProposalRequest {
  id: string;
  property_id?: string | null;
  status?: string;
  total_estimated_value?: number | null;
  expires_at?: string | null;
  source_campaign_id?: string | null;
}

export interface CreateProposalItemRequest {
  proposal_id: string;
  item_type: string;
  plan_id?: string;
  monetization_package_id?: string;
  reference_id?: string;
  quantity?: number;
  price_estimate?: number;
}

export interface UpdateProposalItemRequest {
  id: string;
  item_type?: string;
  plan_id?: string | null;
  monetization_package_id?: string | null;
  reference_id?: string | null;
  quantity?: number;
  price_estimate?: number | null;
}

export interface CreatePackageRequest {
  name: string;
  description?: string;
  package_type: string;
  device_bundle_id?: string;
  base_price?: number;
  is_active?: boolean;
}

export interface UpdatePackageRequest {
  id: string;
  name?: string;
  description?: string | null;
  package_type?: string;
  device_bundle_id?: string | null;
  base_price?: number | null;
  is_active?: boolean;
}

export interface CreateUpsellCampaignRequest {
  tenant_id?: string;
  trigger_event?: string;
  target_package_id?: string;
  campaign_rules?: Record<string, unknown>;
  is_active?: boolean;
}

export interface UpdateUpsellCampaignRequest {
  id: string;
  trigger_event?: string | null;
  target_package_id?: string | null;
  campaign_rules?: Record<string, unknown> | null;
  is_active?: boolean;
}
