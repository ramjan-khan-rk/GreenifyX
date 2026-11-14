import assert from "node:assert/strict";
import { test } from "node:test";
import zlib from "zlib";
import { buildPdf, buildXlsx, buildZip, crc32, pdfText, toCsv } from "../utils/reportFiles.js";

/** Read the entries of a zip we wrote (for checking). */
const readZip = (buf) => {
  const out = {};
  let p = 0;
  while (buf.readUInt32LE(p) === 0x04034b50) {
    const crc = buf.readUInt32LE(p + 14);
    const size = buf.readUInt32LE(p + 18);
    const nameLen = buf.readUInt16LE(p + 26);
    const name = buf.slice(p + 30, p + 30 + nameLen).toString("utf8");
    const data = zlib.inflateRawSync(buf.slice(p + 30 + nameLen, p + 30 + nameLen + size));
    out[name] = { data: data.toString("utf8"), crcOk: crc32(data) === crc };
    p += 30 + nameLen + size;
  }
  return out;
};

test("crc32 matches the known value", () => {
  assert.equal(crc32(Buffer.from("123456789")), 0xcbf43926);
});

test("zip entries round-trip with correct checksums", () => {
  const z = readZip(buildZip([{ name: "a.txt", data: "hello" }, { name: "b/c.xml", data: "<x/>" }]));
  assert.equal(z["a.txt"].data, "hello");
  assert.equal(z["b/c.xml"].crcOk, true);
});

test("xlsx has the workbook parts, keeps Arabic and numbers", () => {
  const z = readZip(buildXlsx([{ name: "Summary", rows: [["Metric", "Value"], ["عائلة", 12.5]] }]));
  assert.ok(z["[Content_Types].xml"]);
  assert.match(z["xl/workbook.xml"].data, /name="Summary"/);
  assert.match(z["xl/worksheets/sheet1.xml"].data, /عائلة/);
  assert.match(z["xl/worksheets/sheet1.xml"].data, /<v>12.5<\/v>/);
});

test("pdf is well formed and escapes text", () => {
  const pdf = buildPdf([{ type: "title", text: "Impact (Nov)" }, { type: "table", rows: [["A", "B"], ["1", "2"]] }], { title: "T" }).toString("latin1");
  assert.ok(pdf.startsWith("%PDF-1.4"));
  assert.ok(pdf.trimEnd().endsWith("%%EOF"));
  assert.match(pdf, /Impact \\\(Nov\\\)/);
  assert.equal(pdfText("CO₂ سارة"), "CO2 ????");
});

test("csv quotes commas and has a BOM for Excel", () => {
  const c = toCsv([["a,b", 'say "hi"'], [1, 2]]);
  assert.ok(c.startsWith("﻿"));
  assert.match(c, /"a,b","say ""hi"""/);
});
