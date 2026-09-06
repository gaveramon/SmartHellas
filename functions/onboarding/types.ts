export interface OnboardingSessionRow {
  id: string;
  tenant_id: string;
  property_id: string;
  preconfig_template_id: string | null;
  onboarding_blueprint_id: string | null;
  status: string;
  current_step: string | null;
  created_at: string;
  updated_at: string;
}

export interface OnboardingStepStateRow {
  id: string;
  tenant_id: string;
  session_id: string;
  step_type: string;
  status: string;
  completed_at: string | null;
}

export interface OnboardingRoomMappingRow {
  id: string;
  tenant_id: string;
  session_id: string;
  room_name: string;
  room_type: string | null;
  promoted_room_id: string | null;
  created_at: string;
}

export interface OnboardingDeviceMappingRow {
  id: string;
  tenant_id: string;
  session_id: string;
  category_code: string | null;
  room_name: string | null;
  desired_action: string | null;
  device_id: string | null;
  scan_status: string;
  scanned_at: string | null;
  created_at: string;
}

export interface OnboardingChecklistRow {
  id: string;
  tenant_id: string;
  session_id: string;
  checklist_key: string;
  is_completed: boolean;
  updated_at: string;
}

export interface OnboardingNoteRow {
  id: string;
  tenant_id: string;
  session_id: string;
  author_user_id: string | null;
  note: string | null;
  created_at: string;
}

export interface OnboardingSessionDetail {
  session: OnboardingSessionRow;
  steps: OnboardingStepStateRow[];
  room_mappings: OnboardingRoomMappingRow[];
  device_mappings: OnboardingDeviceMappingRow[];
  checklist: OnboardingChecklistRow[];
  notes: OnboardingNoteRow[];
}

export interface CreateOnboardingSessionRequest {
  property_id: string;
  preconfig_template_id?: string;
  onboarding_blueprint_id?: string;
  status?: string;
  current_step?: string;
}

export interface UpdateOnboardingSessionRequest {
  id: string;
  preconfig_template_id?: string | null;
  onboarding_blueprint_id?: string | null;
  status?: string;
  current_step?: string | null;
}

export interface UpdateStepStateRequest {
  id: string;
  status?: string;
  completed_at?: string | null;
}

export interface CreateRoomMappingRequest {
  session_id: string;
  room_name: string;
  room_type?: string;
}

export interface UpdateRoomMappingRequest {
  id: string;
  room_name?: string;
  room_type?: string | null;
  promoted_room_id?: string | null;
}

export interface CreateDeviceMappingRequest {
  session_id: string;
  category_code?: string;
  room_name?: string;
  desired_action?: string;
  scan_status?: string;
}

export interface UpdateDeviceMappingRequest {
  id: string;
  category_code?: string | null;
  room_name?: string | null;
  desired_action?: string | null;
  device_id?: string | null;
  scan_status?: string;
  scanned_at?: string | null;
}

export interface UpsertChecklistItemRequest {
  session_id: string;
  checklist_key: string;
  is_completed?: boolean;
}

export interface UpdateChecklistItemRequest {
  id: string;
  is_completed?: boolean;
}

export interface CreateOnboardingNoteRequest {
  session_id: string;
  note: string;
}

export interface OnboardingLifecycleRow {
  id: string;
  tenant_id: string;
  property_id: string;
  session_id: string | null;
  current_state: string;
  created_at: string;
  updated_at: string;
}

export interface OnboardingLifecycleTransitionRow {
  id: string;
  lifecycle_id: string;
  from_state: string | null;
  to_state: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface LifecycleTransitionRequest {
  property_id: string;
  to_state: string;
  metadata?: Record<string, unknown>;
}
