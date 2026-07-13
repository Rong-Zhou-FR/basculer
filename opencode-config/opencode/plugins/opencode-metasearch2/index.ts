import { type Plugin, tool } from "@opencode-ai/plugin";
import { MetasearchService, type SearchType } from "./service.ts";

const PLUGIN_MARKER = "opencode-metasearch2";

const WEB_SEARCH_GUIDANCE = `<WEB_SEARCH_TOOL>
You have a \`web_search\` tool that searches the web using a local metasearch engine.

| Tool | Use when |
|------|----------|
| \`web_search\` | Searching the web for current information, news, documentation, or any query that benefits from aggregating Google, Bing, Brave, and other engines |

**Arguments:**
- \`query\` (string, required) — The search query
- \`type\` ("all" | "images", default "all") — \`"all"\` for web results, \`"images"\` for image search

**Response format:** Raw JSON array. Each tab has \`search_results\` (for web) or \`image_results\` (for images). Results include \`result\`, \`engines\` (which search engines found it), and \`score\`.

No API keys required. Runs a local meta-search engine.
</WEB_SEARCH_TOOL>`;

export const MetasearchPlugin: Plugin = async ({ client }) => {
  const service = new MetasearchService();
  let started = false;

  try {
    await service.start();
    started = true;
  } catch (e) {
    client?.app?.log?.({ body: { service: PLUGIN_MARKER, level: "error", message: `start failed: ${e}` } }).catch(() => {});
    return {};
  }

  client?.app?.log?.({ body: { service: PLUGIN_MARKER, level: "info", message: "metasearch started" } }).catch(() => {});

  return {
    config: async (config) => {
      if (!started) return;
      client?.app?.log?.({ body: { service: PLUGIN_MARKER, level: "info", message: "config hook fired" } }).catch(() => {});
      config.instructions = config.instructions ?? [];
      const hasMarker = config.instructions.some(
        (item) => typeof item === "string" && item.includes(PLUGIN_MARKER),
      );
      if (!hasMarker) {
        config.instructions.push(
          `${PLUGIN_MARKER}: web_search tool available — use for general-purpose web search`,
        );
        client?.app?.log?.({ body: { service: PLUGIN_MARKER, level: "info", message: "config hook: instruction pushed" } }).catch(() => {});
      }
    },

    "experimental.chat.messages.transform": async (_input, output) => {
      client?.app?.log?.({ body: { service: PLUGIN_MARKER, level: "info", message: `transform fired, started=${started}, msgs=${output.messages?.length}` } }).catch(() => {});
      if (!started || !output.messages.length) return;

      const firstUser = output.messages.find((m) => m.info?.role === "user");
      client?.app?.log?.({ body: { service: PLUGIN_MARKER, level: "info", message: `transform: firstUser=${!!firstUser}, parts=${firstUser?.parts?.length}, role=${firstUser?.info?.role}` } }).catch(() => {});
      if (!firstUser?.parts.length) return;
      const hasTag = firstUser.parts.some((p) => p.type === "text" && typeof p.text === "string" && p.text.includes("<WEB_SEARCH_TOOL>"));
      client?.app?.log?.({ body: { service: PLUGIN_MARKER, level: "info", message: `transform: hasTag=${hasTag}, parts[0].type=${firstUser.parts[0]?.type}` } }).catch(() => {});
      if (hasTag) return;

      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: "text", text: WEB_SEARCH_GUIDANCE });
      client?.app?.log?.({ body: { service: PLUGIN_MARKER, level: "info", message: "transform: injection done" } }).catch(() => {});
    },

    "experimental.session.compacting": async (_input, output) => {
      if (!started) return;
      client?.app?.log?.({ body: { service: PLUGIN_MARKER, level: "info", message: "compacting hook fired" } }).catch(() => {});
      output.context.push(`
## Web Search (${PLUGIN_MARKER})
You have \`web_search\` tool for general-purpose web search.
Arguments: query (string, required), type ("all" | "images", default "all").
Runs a local metasearch engine — no API key needed.
`);
    },

    tool: {
      web_search: tool({
        description:
          "Search the web using a local metasearch engine that aggregates results from Google, Bing, Brave, and others. " +
          "Returns raw JSON with search results, featured snippets, direct answers, and infoboxes. " +
          'Set type to "images" for image search.',
        args: {
          query: tool.schema.string().describe("The search query"),
          type: tool.schema
            .enum(["all", "images"])
            .default("all")
            .describe('Search type: "all" for web results, "images" for image search'),
        },
        async execute(args) {
          return service.search(args.query, args.type as SearchType);
        },
      }),
    },
  };
};

export default MetasearchPlugin;
