import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createPipelineStage, listPipelineStages } from "../service.ts";
import { parseCreatePipelineStageBody, parseUuidQuery } from "../validation.ts";

export const pipelineStagesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listPipelineStages(auth, parseUuidQuery(req, "pipeline_id")));
            }
            if (req.method === "POST") {
              const created = await createPipelineStage(
                auth,
                parseCreatePipelineStageBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.pipeline_stage.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for pipeline-stages");
};
