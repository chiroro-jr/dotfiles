#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

function fail(message) {
  console.error(`Error: ${message}`);
  process.exit(1);
}

function isTexelModuleMissing(error) {
  return (
    error &&
    error.code === "ERR_MODULE_NOT_FOUND" &&
    String(error.message || "").includes("@texel/color")
  );
}

function ensureRuntimeDir(cacheDir) {
  fs.mkdirSync(cacheDir, { recursive: true });
  const packageJsonPath = path.join(cacheDir, "package.json");
  if (!fs.existsSync(packageJsonPath)) {
    fs.writeFileSync(
      packageJsonPath,
      JSON.stringify({
        name: "oklch-skill-runtime",
        private: true,
        type: "module",
      }, null, 2),
    );
  }
}

function installTexelColor(cacheDir) {
  ensureRuntimeDir(cacheDir);
  const result = spawnSync(
    "npm",
    ["install", "--no-audit", "--no-fund", "--silent", "@texel/color@latest"],
    { cwd: cacheDir, stdio: "inherit" },
  );
  if (result.status !== 0) {
    fail("Failed to install @texel/color runtime dependency.");
  }
}

async function importTexelFrom(cacheDir) {
  const entry = path.join(cacheDir, "node_modules", "@texel", "color", "src", "index.js");
  if (!fs.existsSync(entry)) {
    fail(`Could not find @texel/color runtime entry at ${entry}`);
  }
  return import(pathToFileURL(entry).href);
}

async function loadTexelModule() {
  try {
    return await import("@texel/color");
  } catch (error) {
    if (!isTexelModuleMissing(error)) {
      throw error;
    }
  }

  const cacheDir = process.env.OKLCH_TEXEL_CACHE || path.join(os.homedir(), ".cache", "oklch-skill", "runtime");
  const installedMarker = path.join(cacheDir, "node_modules", "@texel", "color", "package.json");

  if (!fs.existsSync(installedMarker)) {
    console.error(`Installing @texel/color into ${cacheDir} ...`);
    installTexelColor(cacheDir);
  }

  return importTexelFrom(cacheDir);
}

const texel = await loadTexelModule();

const {
  convert,
  serialize,
  deserialize,
  listColorSpaces,
  gamutMapOKLCH,
  sRGBGamut,
  DisplayP3Gamut,
  Rec2020Gamut,
  A98RGBGamut,
  MapToL,
  MapToGray,
  MapToCuspL,
  MapToAdaptiveGray,
  MapToAdaptiveCuspL,
} = texel;

const HELP = `
texel-convert.mjs

Convert colors between color spaces using @texel/color.

Usage:
  --list-spaces
  --input "oklch(0.62 0.19 264)" --to srgb [--json] [--precision 6]
  --from srgb --coords "0.2,0.4,0.8" --to oklch [--json] [--precision 6]
  --input "oklch(0.7 0.4 40)" --to srgb --gamut srgb --mapping adaptive-cusp

Flags:
  --input <color-string>  Parse source color string with deserialize().
  --from <space-id>       Source space (required with --coords).
  --coords <a,b,c[,a]>    Source coordinates when --input is not used.
  --to <space-id>         Target color space id.
  --gamut <id>            Optional gamut mapping for OKLCH source: srgb|display-p3|rec2020|a98-rgb.
  --mapping <id>          Optional mapping strategy: cusp|adaptive-cusp|l|gray|adaptive-gray.
  --precision <n>         Decimal places for numeric output (default: 6).
  --list-spaces           Print supported color spaces and exit.
  --json                  Print JSON output.
  --no-serialize          Skip CSS string serialization.
  --help                  Show this message.
`;

function parseArgs(argv) {
  const args = {};
  let index = 0;
  while (index < argv.length) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      fail(`Unexpected argument: ${token}`);
    }
    const key = token.slice(2);
    if (["json", "help", "list-spaces", "no-serialize"].includes(key)) {
      args[key] = true;
      index += 1;
      continue;
    }
    const value = argv[index + 1];
    if (value === undefined || value.startsWith("--")) {
      fail(`Missing value for --${key}`);
    }
    args[key] = value;
    index += 2;
  }
  return args;
}

function normalizeId(value) {
  return value.toLowerCase().replace(/[\s_]+/g, "-").trim();
}

function parseCoords(raw) {
  const parts = raw
    .split(/[\s,]+/)
    .map((item) => item.trim())
    .filter(Boolean)
    .map(Number);
  if (parts.length < 3 || parts.some((value) => Number.isNaN(value))) {
    fail(`Invalid coords string: ${raw}`);
  }
  return parts;
}

function roundVec(values, precision) {
  const factor = 10 ** precision;
  return values.map((v) => Math.round(v * factor) / factor);
}

function resolveSpace(id, spaceMap, aliases) {
  const key = normalizeId(id);
  const canonical = aliases.get(key) ?? key;
  const space = spaceMap.get(canonical);
  if (!space) {
    fail(`Unknown color space: ${id}`);
  }
  return space;
}

function resolveGamut(id) {
  const key = normalizeId(id);
  const map = new Map([
    ["srgb", sRGBGamut],
    ["rgb", sRGBGamut],
    ["display-p3", DisplayP3Gamut],
    ["displayp3", DisplayP3Gamut],
    ["p3", DisplayP3Gamut],
    ["rec2020", Rec2020Gamut],
    ["rec-2020", Rec2020Gamut],
    ["a98-rgb", A98RGBGamut],
    ["a98", A98RGBGamut],
  ]);
  const gamut = map.get(key);
  if (!gamut) {
    fail(`Unknown gamut: ${id}`);
  }
  return gamut;
}

function resolveMapping(id) {
  const key = normalizeId(id);
  const map = new Map([
    ["cusp", MapToCuspL],
    ["adaptive-cusp", MapToAdaptiveCuspL],
    ["l", MapToL],
    ["gray", MapToGray],
    ["adaptive-gray", MapToAdaptiveGray],
  ]);
  const mapping = map.get(key);
  if (!mapping) {
    fail(`Unknown mapping strategy: ${id}`);
  }
  return mapping;
}

const args = parseArgs(process.argv.slice(2));

if (args.help || Object.keys(args).length === 0) {
  process.stdout.write(HELP);
  process.exit(0);
}

const spaces = listColorSpaces();
const spaceMap = new Map();
for (const space of spaces) {
  spaceMap.set(normalizeId(space.id), space);
}

const aliases = new Map([
  ["rgb", "srgb"],
  ["srgb", "srgb"],
  ["srgb-linear", "srgb-linear"],
  ["oklch", "oklch"],
  ["oklab", "oklab"],
  ["okhsl", "okhsl"],
  ["okhsv", "okhsv"],
  ["displayp3", "display-p3"],
  ["p3", "display-p3"],
  ["display-p3", "display-p3"],
  ["display-p3-linear", "display-p3-linear"],
  ["xyzd50", "xyz-d50"],
]);

if (args["list-spaces"]) {
  const ids = spaces.map((space) => space.id).sort();
  for (const id of ids) {
    console.log(id);
  }
  process.exit(0);
}

if (!args.to) {
  fail("Missing --to target space.");
}

const toSpace = resolveSpace(args.to, spaceMap, aliases);
const precision = args.precision ? Number(args.precision) : 6;
if (!Number.isInteger(precision) || precision < 0 || precision > 15) {
  fail("--precision must be an integer between 0 and 15.");
}

let fromSpace;
let sourceCoords;
let alpha;

if (args.input) {
  const parsed = deserialize(args.input);
  if (!parsed || !parsed.id || !parsed.coords) {
    fail("Could not deserialize --input color string.");
  }
  fromSpace = resolveSpace(parsed.id, spaceMap, aliases);
  sourceCoords = parsed.coords;
  alpha = sourceCoords.length > 3 ? sourceCoords[3] : undefined;
} else {
  if (!args.from || !args.coords) {
    fail("Use --input ... or use both --from and --coords.");
  }
  fromSpace = resolveSpace(args.from, spaceMap, aliases);
  sourceCoords = parseCoords(args.coords);
  alpha = sourceCoords.length > 3 ? sourceCoords[3] : undefined;
}

const source3 = sourceCoords.slice(0, 3);
if (source3.length !== 3) {
  fail("Source coordinates must contain at least 3 numeric values.");
}

let output;
let usedGamut = null;
let usedMapping = null;

if (args.gamut || args.mapping) {
  if (fromSpace.id !== "oklch") {
    fail("Gamut mapping requires OKLCH source input.");
  }
  const gamut = resolveGamut(args.gamut ?? "srgb");
  const mapping = resolveMapping(args.mapping ?? "cusp");
  output = gamutMapOKLCH(source3, gamut, toSpace, undefined, mapping);
  usedGamut = gamut.id;
  usedMapping = args.mapping ?? "cusp";
} else {
  output = convert(source3, fromSpace, toSpace);
}

let css = null;
let serializeError = null;
if (!args["no-serialize"]) {
  try {
    const coordsForCss = alpha === undefined ? output : [...output, alpha];
    css = serialize(coordsForCss, toSpace);
  } catch (error) {
    serializeError = error instanceof Error ? error.message : String(error);
  }
}

const result = {
  from: fromSpace.id,
  to: toSpace.id,
  source: roundVec(source3, precision),
  output: roundVec(output, precision),
  alpha: alpha === undefined ? null : alpha,
  gamut: usedGamut,
  mapping: usedMapping,
  css,
  serializeError,
};

if (args.json) {
  console.log(JSON.stringify(result, null, 2));
} else {
  console.log(`from: ${result.from}`);
  console.log(`to: ${result.to}`);
  console.log(`source: ${JSON.stringify(result.source)}`);
  console.log(`output: ${JSON.stringify(result.output)}`);
  if (result.alpha !== null) console.log(`alpha: ${result.alpha}`);
  if (result.gamut) console.log(`gamut: ${result.gamut}`);
  if (result.mapping) console.log(`mapping: ${result.mapping}`);
  if (result.css) console.log(`css: ${result.css}`);
  if (result.serializeError) console.log(`serializeError: ${result.serializeError}`);
}
