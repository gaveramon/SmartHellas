import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deletePipeline, getPipeline, updatePipeline } from "../service.ts";
import { parseDeleteIdBody, parseUpdatePipelineBody, parseUuidQuery } from "../validation.ts";

export const pipelineHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") return success(await getPipeline(auth, parseUuidQuery(req)));
            if (req.method === "PATCH") {
              const updated = await updatePipeline(auth, parseUpdatePipelineBody(await parseJsonBody(req)));
              await logger.audit("crm.pipeline.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deletePipeline(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.pipeline.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for pipeline");
};
