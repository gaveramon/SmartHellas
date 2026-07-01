import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  CreateDeviceMappingRequest,
  CreateOnboardingNoteRequest,
  CreateOnboardingSessionRequest,
  CreateRoomMappingRequest,
  OnboardingChecklistRow,
  OnboardingDeviceMappingRow,
  OnboardingNoteRow,
  OnboardingRoomMappingRow,
  OnboardingSessionDetail,
  OnboardingSessionRow,
  OnboardingStepStateRow,
  UpdateChecklistItemRequest,
  UpdateDeviceMappingRequest,
  UpdateOnboardingSessionRequest,
  UpdateRoomMappingRequest,
  UpdateStepStateRequest,
  UpsertChecklistItemRequest,
  OnboardingLifecycleRow,
  OnboardingLifecycleTransitionRow,
  LifecycleTransitionRequest,
} from "./types.ts";

function tid(auth: AuthContext): string {
  return requireTenant(auth);
}

export async function listOnboardingSessions(
  auth: AuthContext,
  propertyId?: string,
): Promise<OnboardingSessionRow[]> {
  tid(auth);
  return await callModuleApiAuth<OnboardingSessionRow[]>(
    auth,
    "onboarding",
    "list_sessions",
    propertyId ? { property_id: propertyId } : {},
  );
}

export async function getOnboardingSession(
  auth: AuthContext,
  id: string,
): Promise<OnboardingSessionDetail> {
  tid(auth);
  return await callModuleApiAuth<OnboardingSessionDetail>(
    auth,
    "onboarding",
    "get_session",
    { id },
  );
}

export async function createOnboardingSession(
  auth: AuthContext,
  input: CreateOnboardingSessionRequest,
): Promise<OnboardingSessionRow> {
  return await callModuleApiAuth<OnboardingSessionRow>(
    auth,
    "onboarding",
    "create_session",
    { ...input },
  );
}

export async function updateOnboardingSession(
  auth: AuthContext,
  input: UpdateOnboardingSessionRequest,
): Promise<OnboardingSessionRow> {
  return await callModuleApiAuth<OnboardingSessionRow>(
    auth,
    "onboarding",
    "update_session",
    { ...input },
  );
}

export async function deleteOnboardingSession(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth(auth, "onboarding", "delete_session", { id });
}

export async function listStepStates(
  auth: AuthContext,
  sessionId: string,
): Promise<OnboardingStepStateRow[]> {
  tid(auth);
  return await callModuleApiAuth<OnboardingStepStateRow[]>(
    auth,
    "onboarding",
    "list_step_states",
    { session_id: sessionId },
  );
}

export async function updateStepState(
  auth: AuthContext,
  input: UpdateStepStateRequest,
): Promise<OnboardingStepStateRow> {
  return await callModuleApiAuth<OnboardingStepStateRow>(
    auth,
    "onboarding",
    "update_step_state",
    { ...input },
  );
}

export async function listRoomMappings(
  auth: AuthContext,
  sessionId: string,
): Promise<OnboardingRoomMappingRow[]> {
  tid(auth);
  return await callModuleApiAuth<OnboardingRoomMappingRow[]>(
    auth,
    "onboarding",
    "list_room_mappings",
    { session_id: sessionId },
  );
}

export async function createRoomMapping(
  auth: AuthContext,
  input: CreateRoomMappingRequest,
): Promise<OnboardingRoomMappingRow> {
  return await callModuleApiAuth<OnboardingRoomMappingRow>(
    auth,
    "onboarding",
    "create_room_mapping",
    { ...input },
  );
}

export async function updateRoomMapping(
  auth: AuthContext,
  input: UpdateRoomMappingRequest,
): Promise<OnboardingRoomMappingRow> {
  return await callModuleApiAuth<OnboardingRoomMappingRow>(
    auth,
    "onboarding",
    "update_room_mapping",
    { ...input },
  );
}

export async function deleteRoomMapping(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth(auth, "onboarding", "delete_room_mapping", { id });
}

export async function listDeviceMappings(
  auth: AuthContext,
  sessionId: string,
): Promise<OnboardingDeviceMappingRow[]> {
  tid(auth);
  return await callModuleApiAuth<OnboardingDeviceMappingRow[]>(
    auth,
    "onboarding",
    "list_device_mappings",
    { session_id: sessionId },
  );
}

export async function createDeviceMapping(
  auth: AuthContext,
  input: CreateDeviceMappingRequest,
): Promise<OnboardingDeviceMappingRow> {
  return await callModuleApiAuth<OnboardingDeviceMappingRow>(
    auth,
    "onboarding",
    "create_device_mapping",
    { ...input },
  );
}

export async function updateDeviceMapping(
  auth: AuthContext,
  input: UpdateDeviceMappingRequest,
): Promise<OnboardingDeviceMappingRow> {
  return await callModuleApiAuth<OnboardingDeviceMappingRow>(
    auth,
    "onboarding",
    "update_device_mapping",
    { ...input },
  );
}

export async function deleteDeviceMapping(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth(auth, "onboarding", "delete_device_mapping", { id });
}

export async function listChecklistItems(
  auth: AuthContext,
  sessionId: string,
): Promise<OnboardingChecklistRow[]> {
  tid(auth);
  return await callModuleApiAuth<OnboardingChecklistRow[]>(
    auth,
    "onboarding",
    "list_checklist_items",
    { session_id: sessionId },
  );
}

export async function upsertChecklistItem(
  auth: AuthContext,
  input: UpsertChecklistItemRequest,
): Promise<OnboardingChecklistRow> {
  return await callModuleApiAuth<OnboardingChecklistRow>(
    auth,
    "onboarding",
    "upsert_checklist_item",
    { ...input },
  );
}

export async function updateChecklistItem(
  auth: AuthContext,
  input: UpdateChecklistItemRequest,
): Promise<OnboardingChecklistRow> {
  return await callModuleApiAuth<OnboardingChecklistRow>(
    auth,
    "onboarding",
    "update_checklist_item",
    { ...input },
  );
}

export async function deleteChecklistItem(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth(auth, "onboarding", "delete_checklist_item", { id });
}

export async function listNotes(
  auth: AuthContext,
  sessionId: string,
): Promise<OnboardingNoteRow[]> {
  tid(auth);
  return await callModuleApiAuth<OnboardingNoteRow[]>(
    auth,
    "onboarding",
    "list_notes",
    { session_id: sessionId },
  );
}

export async function createNote(
  auth: AuthContext,
  input: CreateOnboardingNoteRequest,
): Promise<OnboardingNoteRow> {
  return await callModuleApiAuth<OnboardingNoteRow>(
    auth,
    "onboarding",
    "create_note",
    { ...input },
  );
}

export async function deleteNote(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth(auth, "onboarding", "delete_note", { id });
}

export async function getOnboardingLifecycle(
  auth: AuthContext,
  propertyId: string,
): Promise<OnboardingLifecycleRow | null> {
  tid(auth);
  return await callModuleApiAuth<OnboardingLifecycleRow | null>(
    auth,
    "onboarding",
    "get_lifecycle",
    { property_id: propertyId },
  );
}

export async function listOnboardingLifecycleTransitions(
  auth: AuthContext,
  propertyId: string,
): Promise<OnboardingLifecycleTransitionRow[]> {
  tid(auth);
  return await callModuleApiAuth<OnboardingLifecycleTransitionRow[]>(
    auth,
    "onboarding",
    "list_lifecycle_transitions",
    { property_id: propertyId },
  );
}

export async function transitionOnboardingLifecycle(
  auth: AuthContext,
  input: LifecycleTransitionRequest,
): Promise<OnboardingLifecycleRow> {
  return await callModuleApiAuth<OnboardingLifecycleRow>(
    auth,
    "onboarding",
    "lifecycle_transition",
    {
      property_id: input.property_id,
      to_state: input.to_state,
      metadata: input.metadata ?? {},
    },
  );
}
