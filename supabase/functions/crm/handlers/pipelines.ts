import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createPipeline, listPipelines } from "../service.ts";
import { parseCreatePipelineBody } from "../validation.ts";

export const pipelinesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") return success(await listPipelines(auth));
            if (req.method === "POST") {
              const created = await createPipeline(auth, parseCreatePipelineBody(await parseJsonBody(req)));
              await logger.audit("crm.pipeline.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for pipelines");
};
