// Wraps index.html (written as an artifact body fragment) into a full HTML document for static hosting.
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';

const src = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
const split = src.indexOf('</style>') + '</style>'.length;
const head = src.slice(0, split);
const body = src.slice(split);
const icon = `data:image/svg+xml,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="6" fill="#060807"/><path d="M7 21a11 11 0 0 1 15-15z" fill="#d9dee2"/><path d="M14 14l9-9" stroke="#5cf2df" stroke-width="2.4" stroke-linecap="round"/><path d="M11 22l-3 6h10l-3-6" fill="#8d9296"/></svg>')}`;

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#060807">
<meta name="description" content="A night-time garage rebuilt in code, with a deep-space dish on the roof that beams your message to the Moon, Mars, Voyager 1 or Proxima b.">
<link rel="icon" href="${icon}">
${head}
</head>
<body>
${body}
</body>
</html>
`;

mkdirSync(new URL('./dist/', import.meta.url), { recursive: true });
writeFileSync(new URL('./dist/index.html', import.meta.url), html);
console.log(`dist/index.html written (${html.length} bytes)`);
