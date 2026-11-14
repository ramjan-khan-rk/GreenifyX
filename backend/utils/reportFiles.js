import zlib from "zlib";

/**
 * Report downloads without extra libraries: a real PDF (text and simple tables,
 * A4, built-in Helvetica) and a real Excel .xlsx (zip of XML parts), plus CSV.
 * Note: the PDF uses a standard font, so letters outside Western European
 * (for example Arabic names) are shown as "?". The Excel file keeps every letter.
 */

// ---------- CSV ----------
const csvCell = (v) => {
  const s = v === null || v === undefined ? "" : String(v);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
export const toCsv = (rows) => "﻿" + rows.map((r) => r.map(csvCell).join(",")).join("\r\n");

// ---------- PDF ----------
const WIN_ANSI_EXTRA = { "€": 128, "‘": 145, "’": 146, "“": 147, "”": 148, "–": 150, "—": 151, "•": 149, "…": 133 };
/** Text in a PDF string, Latin-1 only (others become "?"). */
export const pdfText = (s) => {
  let out = "";
  for (const ch of String(s ?? "").replace(/₂/g, "2").replace(/²/g, "2")) {
    let code = ch.codePointAt(0);
    if (WIN_ANSI_EXTRA[ch]) code = WIN_ANSI_EXTRA[ch];
    else if (code > 255 || (code < 32 && ch !== "\t")) code = 63;
    const c = String.fromCharCode(code);
    out += c === "(" || c === ")" || c === "\\" ? `\\${c}` : c;
  }
  return out;
};

/**
 * blocks: [{ type: "title"|"heading"|"text"|"table"|"gap", text, rows: [[...]], widths: [fractions] }]
 */
export const buildPdf = (blocks, { title = "Report" } = {}) => {
  const W = 595;
  const H = 842;
  const M = 50;
  const pages = [];
  let ops = [];
  let y = H - M;
  const newPage = () => {
    if (ops.length) pages.push(ops.join("\n"));
    ops = [];
    y = H - M;
  };
  const ensure = (h) => {
    if (y - h < M) newPage();
  };
  const text = (str, x, size, bold = false) => ops.push(`BT /${bold ? "F2" : "F1"} ${size} Tf ${x.toFixed(1)} ${y.toFixed(1)} Td (${pdfText(str)}) Tj ET`);
  // Rough width for wrapping: Helvetica averages ~0.5em per character.
  const wrap = (str, size, width) => {
    const max = Math.max(8, Math.floor(width / (size * 0.5)));
    const words = String(str ?? "").split(/\s+/);
    const lines = [];
    let line = "";
    for (const w of words) {
      if ((line + " " + w).trim().length > max) {
        if (line) lines.push(line);
        line = w;
      } else line = (line + " " + w).trim();
    }
    if (line) lines.push(line);
    return lines.length ? lines : [""];
  };

  for (const b of blocks) {
    if (b.type === "gap") {
      y -= b.size || 10;
      continue;
    }
    if (b.type === "title" || b.type === "heading" || b.type === "text") {
      const size = b.type === "title" ? 20 : b.type === "heading" ? 13 : 10;
      const lead = size * 1.35;
      for (const line of wrap(b.text, size, W - 2 * M)) {
        ensure(lead);
        y -= lead;
        text(line, M, size, b.type !== "text");
      }
      y -= b.type === "text" ? 4 : 6;
      continue;
    }
    if (b.type === "table") {
      const widths = b.widths || b.rows[0].map(() => 1 / b.rows[0].length);
      const size = 9.5;
      const lead = size * 1.45;
      b.rows.forEach((row, i) => {
        const cells = row.map((c, j) => wrap(c, size, widths[j] * (W - 2 * M) - 6));
        const h = Math.max(...cells.map((c) => c.length)) * lead + 4;
        ensure(h);
        let x = M;
        const top = y;
        cells.forEach((lines, j) => {
          y = top;
          lines.forEach((l) => {
            y -= lead;
            text(l, x + 2, size, i === 0 && b.header !== false);
          });
          x += widths[j] * (W - 2 * M);
        });
        y = top - h;
        ops.push(`0.85 0.82 0.8 RG 0.5 w ${M} ${(y + 1).toFixed(1)} m ${W - M} ${(y + 1).toFixed(1)} l S`);
      });
      y -= 8;
    }
  }
  newPage();

  // Assemble objects: 1 catalog, 2 pages, 3/4 fonts, then page + content pairs.
  const objs = [];
  const pageIds = pages.map((_, i) => 5 + i * 2);
  objs[1] = "<< /Type /Catalog /Pages 2 0 R >>";
  objs[2] = `<< /Type /Pages /Kids [${pageIds.map((id) => `${id} 0 R`).join(" ")}] /Count ${pages.length} >>`;
  objs[3] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>";
  objs[4] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>";
  pages.forEach((content, i) => {
    const pid = pageIds[i];
    const footer = `BT /F1 8 Tf ${M} 28 Td (${pdfText(`${title} - page ${i + 1} of ${pages.length}`)}) Tj ET`;
    const stream = `${content}\n${footer}`;
    objs[pid] = `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${W} ${H}] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents ${pid + 1} 0 R >>`;
    objs[pid + 1] = `<< /Length ${Buffer.byteLength(stream, "latin1")} >>\nstream\n${stream}\nendstream`;
  });
  let pdf = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n";
  const offsets = [];
  for (let i = 1; i < objs.length; i++) {
    offsets[i] = Buffer.byteLength(pdf, "latin1");
    pdf += `${i} 0 obj\n${objs[i]}\nendobj\n`;
  }
  const xref = Buffer.byteLength(pdf, "latin1");
  pdf += `xref\n0 ${objs.length}\n0000000000 65535 f \n`;
  for (let i = 1; i < objs.length; i++) pdf += `${String(offsets[i]).padStart(10, "0")} 00000 n \n`;
  pdf += `trailer\n<< /Size ${objs.length} /Root 1 0 R /Info << /Title (${pdfText(title)}) /Producer (GreenifyX) >> >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf, "latin1");
};

// ---------- ZIP + XLSX ----------
const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
export const crc32 = (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};

/** files: [{ name, data: Buffer|string }] -> zip Buffer (deflate). */
export const buildZip = (files) => {
  const locals = [];
  const centrals = [];
  let offset = 0;
  for (const f of files) {
    const name = Buffer.from(f.name, "utf8");
    const raw = Buffer.isBuffer(f.data) ? f.data : Buffer.from(f.data, "utf8");
    const comp = zlib.deflateRawSync(raw);
    const crc = crc32(raw);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0x0800, 6); // UTF-8 names
    local.writeUInt16LE(8, 8); // deflate
    local.writeUInt32LE(0, 10); // time/date
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(comp.length, 18);
    local.writeUInt32LE(raw.length, 22);
    local.writeUInt16LE(name.length, 26);
    local.writeUInt16LE(0, 28);
    locals.push(local, name, comp);
    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(0x0800, 8);
    central.writeUInt16LE(8, 10);
    central.writeUInt32LE(0, 12);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(comp.length, 20);
    central.writeUInt32LE(raw.length, 24);
    central.writeUInt16LE(name.length, 28);
    central.writeUInt32LE(offset, 42);
    centrals.push(central, name);
    offset += 30 + name.length + comp.length;
  }
  const cd = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(cd.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, cd, end]);
};

const xml = (s) =>
  String(s ?? "")
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
const colName = (i) => {
  let s = "";
  for (let n = i + 1; n > 0; n = Math.floor((n - 1) / 26)) s = String.fromCharCode(65 + ((n - 1) % 26)) + s;
  return s;
};

/** sheets: [{ name, rows: [[cell...]] }] -> .xlsx Buffer. Numbers stay numbers; the first row is bold. */
export const buildXlsx = (sheets) => {
  const safe = sheets.map((s, i) => ({ ...s, name: xml(String(s.name || `Sheet${i + 1}`).replace(/[\\/?*[\]:]/g, " ").slice(0, 31)) }));
  const sheetXml = (rows) =>
    `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>` +
    rows
      .map(
        (r, ri) =>
          `<row r="${ri + 1}">` +
          r
            .map((v, ci) => {
              const ref = `${colName(ci)}${ri + 1}`;
              const style = ri === 0 ? ' s="1"' : "";
              if (typeof v === "number" && Number.isFinite(v)) return `<c r="${ref}"${style}><v>${v}</v></c>`;
              return `<c r="${ref}" t="inlineStr"${style}><is><t xml:space="preserve">${xml(v)}</t></is></c>`;
            })
            .join("") +
          `</row>`
      )
      .join("") +
    `</sheetData></worksheet>`;
  const files = [
    {
      name: "[Content_Types].xml",
      data:
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` +
        `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>` +
        `<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>` +
        `<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>` +
        safe.map((_, i) => `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join("") +
        `</Types>`,
    },
    {
      name: "_rels/.rels",
      data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
    },
    {
      name: "xl/workbook.xml",
      data:
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>` +
        safe.map((s, i) => `<sheet name="${s.name}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join("") +
        `</sheets></workbook>`,
    },
    {
      name: "xl/_rels/workbook.xml.rels",
      data:
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` +
        safe.map((_, i) => `<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>`).join("") +
        `<Relationship Id="rId${safe.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`,
    },
    {
      name: "xl/styles.xml",
      data:
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">` +
        `<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>` +
        `<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>` +
        `<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>` +
        `<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>` +
        `<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>` +
        `</styleSheet>`,
    },
    ...safe.map((s, i) => ({ name: `xl/worksheets/sheet${i + 1}.xml`, data: sheetXml(s.rows) })),
  ];
  return buildZip(files);
};
