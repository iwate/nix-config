import { basename, join, dirname } from "jsr:@std/path";
import { walk } from "jsr:@std/fs";
import { render } from "jsr:@deno/gfm";
import { DOMParser } from "jsr:@b-fuze/deno-dom";
import { BlobWriter, ZipWriter} from "jsr:@zip-js/zip-js";

const input_file_name = Deno.args[0];
const output_dir_name = "/home/iwate/works/blog";
const build_dir_name = await Deno.makeTempDir();

if (!input_file_name) {
  console.error("md2blog <input file path>");
  Deno.exit(1);
} 

const markdown = await Deno.readTextFile(input_file_name);
let body = render(markdown, { allowMath: false, allowIframes: true });

const stat = await Deno.stat(input_file_name)
const createdAt = formatDate(stat.ctime ?? new Date());
const updatedAt = formatDate(stat.mtime ?? new Date());

const doc = new DOMParser().parseFromString(body, "text/html");
const description = doc.querySelector("p")?.innerText;
let title = doc.querySelector("h1")?.innerText;

if (!title) {
  title = basename(input_file_name).replace(/\.[^/.]+$/, "");
  body = `${title}\n${body}`;
}

body = await transformImageTag(body);

const html = `
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">
    <meta name="description" content="${description}">
    <title>${title}</title>
    <meta name="created-at" content="${createdAt}">
    <meta name="updated-at" content="${updatedAt}">
    <style>[aria-hidden="true"] { display: none; }</style>
  </head>
  <body>
    ${body}
  </body>
</html>
`;

await Deno.writeTextFile(join(build_dir_name, title.replace(/[、。]/,"") + ".html"), html);

const zipBlob = await compress(build_dir_name);
await Deno.writeFile(join(output_dir_name, 'output.zip'), zipBlob.stream())

await Deno.remove(build_dir_name, { recursive: true });

// --- helpers

function formatDate(date: Date) {
  // 月を取得（0から始まるので1を足す）
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  
  // 日を取得
  const day = String(date.getUTCDate()).padStart(2, '0');
  
  // 年を取得
  const year = date.getUTCFullYear();
  
  // 時間を取得（12時間制）
  let hours: number | string = date.getUTCHours();
  const ampm = hours >= 12 ? 'PM' : 'AM';
  hours = hours % 12;
  hours = hours ? hours : 12; // 0時は12時と表示
  hours = String(hours).padStart(2, '0');
  
  // 分を取得
  const minutes = String(date.getUTCMinutes()).padStart(2, '0');
  
  // フォーマットした文字列を返す
  return `${day}-${month}-${year} ${hours}:${minutes} ${ampm}`;
}

async function transformImageTag(body: string): Promise<string> {
  const dir = join(build_dir_name, 'attachments');
  await Deno.mkdir(dir);
  return body.replace(/!\[\[.*?\]\]/g, (match) => {
    const file = match.substring(3, match.length - 2);
    const src = join(dirname(input_file_name), 'attachments', file);
    const dst = join(dir, file);
    Deno.copyFileSync(src, dst);
    return `<img src="/attachments/${file}">`;
  })
}

async function compress(dir: string): Promise<Blob> {
  const blobWriter = new BlobWriter();
  const zipWriter = new ZipWriter(blobWriter);

  for await (const entry of walk(dir)) {
    if (entry.isFile) {
      const relativePath = entry.path.replace(dir + "/", "");
      const fileData = await Deno.readFile(entry.path);
      await zipWriter.add(relativePath, new Blob([fileData]).stream());
    }
  }

  zipWriter.close();

  return blobWriter.getData()
}