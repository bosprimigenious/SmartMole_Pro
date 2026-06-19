#!/usr/bin/env node
/** Symlink public/images and public/svg to sibling asset dirs (Windows junction / Unix symlink). */
import { existsSync, mkdirSync, rmSync, symlinkSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const publicDir = join(root, "public");
const links = [
  ["images", join(root, "..", "assets", "images")],
  ["svg", join(root, "..", "svg")],
];

mkdirSync(publicDir, { recursive: true });

for (const [name, target] of links) {
  const link = join(publicDir, name);
  if (existsSync(link)) {
    try { rmSync(link, { recursive: true, force: true }); } catch { /* ignore */ }
  }
  if (!existsSync(target)) {
    console.warn(`WARN: target missing ${target}`);
    continue;
  }
  symlinkSync(target, link, "junction");
  console.log(`Linked public/${name} → ${target}`);
}
