import { join, parse } from "node:path";

const args = [...Deno.args];
let inputPath: string | undefined;
let sourceLang = "ja";
let targetLang = "en";

for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--help" || arg === "-h") {
    console.log("Usage: translate <file> [--lang <src>:<dst>]");
    Deno.exit(0);
  }
  if (arg === "--lang") {
    const languagePair = args[index + 1];
    if (!languagePair) {
      fail("--lang requires a value in the form <src>:<dst>");
    }
    const match = languagePair.match(/^([A-Za-z]{2,3}(?:-[A-Za-z0-9]+)*):([A-Za-z]{2,3}(?:-[A-Za-z0-9]+)*)$/);
    if (!match) {
      fail(`Invalid language pair: ${languagePair}`);
    }
    sourceLang = match[1];
    targetLang = match[2];
    index += 1;
  } else if (arg.startsWith("-")) {
    fail(`Unknown option: ${arg}`);
  } else if (inputPath) {
    fail("Only one input file can be translated at a time");
  } else {
    inputPath = arg;
  }
}

if (!inputPath) {
  fail("Usage: translate <file> [--lang <src>:<dst>]");
}

const input = await Deno.realPath(inputPath).catch(() => {
  fail(`File not found: ${inputPath}`);
});
const fileInfo = await Deno.stat(input);
if (!fileInfo.isFile) {
  fail(`Not a file: ${input}`);
}

const { dir, name, ext } = parse(input);
const outputPath = join(dir || ".", `${name}.${targetLang}${ext}`);
const text = await Deno.readTextFile(input);
const apiBase = Deno.env.get("LEMONADE_BASE_URL") ?? "http://127.0.0.1:13305/api/v1";
const model = Deno.env.get("LEMONADE_MODEL") ?? "plamo-3-translate-8b-GGUF-Q4_K_M";
const chunks = splitIntoChunks(text, 6000);
const translations: string[] = [];

for (let index = 0; index < chunks.length; index += 1) {
  console.error(`Translating part ${index + 1}/${chunks.length} (${sourceLang} -> ${targetLang})...`);
  translations.push(await translateChunk(chunks[index]));
}

await Deno.writeTextFile(outputPath, translations.join("").trimEnd() + "\n");
console.log(`Translated ${input} (${sourceLang} -> ${targetLang})`);
console.log(`Wrote ${outputPath}`);

async function translateChunk(chunk: string): Promise<string> {
  const response = await fetch(`${apiBase.replace(/\/$/, "")}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer EMPTY",
    },
    body: JSON.stringify({
      model,
      messages: [{ role: "user", content: chunk }],
      chat_template_kwargs: {
        source_lang: sourceLang,
        target_lang: targetLang,
      },
      temperature: 0,
      max_tokens: 3072,
      stop: ["<|plamo:tag|>", "<|plamo:bos|>"],
    }),
    signal: AbortSignal.timeout(9 * 60 * 1000),
  });

  if (!response.ok) {
    const detail = await response.text();
    fail(`Lemonade API returned ${response.status}: ${detail}`);
  }

  const result = await response.json();
  const choice = result.choices?.[0];
  const translation = choice?.message?.content;
  if (typeof translation !== "string" || !translation.trim()) {
    fail("Lemonade returned an empty or invalid translation");
  }
  if (choice.finish_reason === "length") {
    fail("A translation part exceeded 3,072 output tokens; reduce the chunk size and retry");
  }
  return translation;
}

function splitIntoChunks(value: string, maxChars: number): string[] {
  const chunks: string[] = [];
  let current = "";

  for (const line of value.match(/[^\n]*\n|[^\n]+$/g) ?? []) {
    const headingSeparator = current.match(/\n[ \t]*\n$/);
    if (
      line.startsWith("#") && headingSeparator &&
      current.length >= maxChars * 0.6
    ) {
      const boundary = headingSeparator.index! + 1;
      chunks.push(current.slice(0, boundary));
      current = current.slice(boundary);
    }

    let remaining = line;
    while (remaining.length > 0) {
      const available = maxChars - current.length;
      if (remaining.length <= available) {
        current += remaining;
        break;
      }

      let splitAt = Math.max(
        remaining.lastIndexOf(" ", available),
        remaining.lastIndexOf("。", available),
        remaining.lastIndexOf("！", available),
        remaining.lastIndexOf("？", available),
      );
      if (splitAt <= 0) splitAt = available;
      else splitAt += 1;

      current += remaining.slice(0, splitAt);
      chunks.push(current);
      current = "";
      remaining = remaining.slice(splitAt);
    }

    if (current.length >= maxChars) {
      chunks.push(current);
      current = "";
    }
  }

  if (current) chunks.push(current);
  return chunks.length > 0 ? chunks : [""];
}

function fail(message: string): never {
  console.error(message);
  Deno.exit(1);
}