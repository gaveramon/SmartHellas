import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deletePipelineStage, updatePipelineStage } from "../service.ts";
import { parseDeleteIdBody, parseUpdatePipelineStageBody } from "../validation.ts";

export const pipelineStageHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updatePipelineStage(
                auth,
                parseUpdatePipelineStageBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.pipeline_stage.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deletePipelineStage(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.pipeline_stage.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for pipeline-stage");
};
