/* Chambers & Light — Desqueeze (web client)
 *
 * The same operation as the macOS and Windows clients: widen by the squeeze
 * factor, leave height untouched (see Services/DesqueezeProcessor.cs).
 *
 * Everything happens in this tab. No network call carries image data, nothing
 * is written to localStorage / sessionStorage / IndexedDB / the Cache API, and
 * there is no service worker. Object URLs are revoked the moment they stop
 * being displayed, so a cleared or removed image is unreachable immediately
 * rather than at the next GC.
 *
 * No dependencies, no build step, no third-party host — which is what keeps
 * this inside the utilities CSP (script-src 'self').
 */
(function () {
  "use strict";

  var MAX_FILES = 36;
  var JPEG_QUALITY = 0.92; // matches JpegBitmapEncoder QualityLevel = 92

  // Kept in lockstep with Models/SqueezePreset.cs.
  var PRESETS = [
    { label: "1.25×", factor: 1.25, glass: "ULTRA STARLESS" },
    { label: "1.33×", factor: 1.33, glass: "HAWK · LOMO" },
    { label: "1.50×", factor: 1.5, glass: "SLR MAGIC" },
    { label: "1.55×", factor: 1.55, glass: "IRON GLASS" },
    { label: "1.60×", factor: 1.6, glass: "VAZEN" },
    { label: "1.65×", factor: 1.65, glass: "COOKE SF" },
    { label: "1.75×", factor: 1.75, glass: "ATLAS MERCURY" },
    { label: "1.80×", factor: 1.8, glass: "KOWA · ISCO" },
    { label: "2.00×", factor: 2.0, glass: "FULL 2× GLASS" },
  ];

  var $ = function (id) {
    return document.getElementById(id);
  };

  var items = []; // { id, file, name, w, h, factor|null, blob|null, url|null, state, error }
  var nextId = 1;
  var globalFactor = 2.0;
  var running = false;

  // ---------------------------------------------------------------- helpers

  function fmtDims(w, h) {
    return w + "×" + h;
  }

  function ratio(w, h) {
    return (w / h).toFixed(2) + ":1";
  }

  function baseName(name) {
    var i = name.lastIndexOf(".");
    return i > 0 ? name.slice(0, i) : name;
  }

  function outName(name, factor, mime) {
    var ext = mime === "image/png" ? "png" : "jpg";
    // 1.50 → "1_50x", so the factor survives in the filename without a dot
    // that would confuse the extension.
    var tag = factor.toFixed(2).replace(".", "_");
    return baseName(name) + "_desqueeze_" + tag + "x." + ext;
  }

  function revoke(item) {
    if (item.url) {
      URL.revokeObjectURL(item.url);
      item.url = null;
    }
    revokeOut(item);
  }

  function revokeOut(item) {
    if (item.outUrl) {
      URL.revokeObjectURL(item.outUrl);
      item.outUrl = null;
    }
  }

  function setMsg(el, text, isError) {
    el.textContent = text;
    el.className = "msg" + (isError ? " error" : "");
  }

  /** Yield to the event loop so the grid repaints between images. */
  function breathe() {
    return new Promise(function (r) {
      setTimeout(r, 0);
    });
  }

  // ------------------------------------------------------------------ EXIF
  //
  // Canvas re-encoding drops every marker, which would lose capture date,
  // camera and lens — metadata the native clients preserve and the reason a
  // photographer would trust this at all. For JPEG output we lift APP1 (the
  // EXIF block) out of the source and splice it into the encoded result, then
  // correct the two pixel-dimension tags so the block does not describe an
  // image that no longer exists (the native clients do the same).
  //
  // Only the 4-byte inline value fields are overwritten, never a length or an
  // offset, so no part of the block moves. Anything unexpected leaves the
  // bytes untouched: stale dimensions are a blemish, corrupted EXIF is damage.

  function findAPP1(bytes) {
    if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) return null; // not JPEG
    var i = 2;
    while (i + 4 <= bytes.length) {
      if (bytes[i] !== 0xff) return null; // desynchronised; give up rather than guess
      var marker = bytes[i + 1];
      if (marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd9)) {
        i += 2;
        continue;
      }
      if (marker === 0xda) return null; // start of scan — no APP1 before the image data
      var len = (bytes[i + 2] << 8) | bytes[i + 3];
      if (len < 2 || i + 2 + len > bytes.length) return null;
      if (marker === 0xe1) return bytes.subarray(i, i + 2 + len);
      i += 2 + len;
    }
    return null;
  }

  /**
   * Rewrite PixelXDimension (0xA002) and PixelYDimension (0xA003) in a copy of
   * the APP1 segment. Returns the input unchanged if the block is not a shape
   * we fully recognise.
   */
  function patchPixelDims(app1, width, height) {
    try {
      // FFE1 len(2) "Exif\0\0"(6) then the TIFF header.
      if (app1.length < 20) return app1;
      var hdr = 4 + 6;
      for (var i = 0; i < 6; i++) {
        if (app1[4 + i] !== [0x45, 0x78, 0x69, 0x66, 0x00, 0x00][i])
          return app1;
      }
      var out = new Uint8Array(app1); // copy — never mutate the source block
      var dv = new DataView(out.buffer, out.byteOffset, out.byteLength);
      var le;
      if (out[hdr] === 0x49 && out[hdr + 1] === 0x49) le = true;
      else if (out[hdr] === 0x4d && out[hdr + 1] === 0x4d) le = false;
      else return app1;
      if (dv.getUint16(hdr + 2, le) !== 0x002a) return app1;

      var ifd0 = hdr + dv.getUint32(hdr + 4, le);
      if (ifd0 + 2 > out.length) return app1;

      // Cameras put the pixel dimensions in the Exif sub-IFD; some writing
      // libraries put them straight in IFD0. Both layouts occur, so walk IFD0
      // for the tags *and* for the 0x8769 pointer, then walk what it points at.
      var found = { patched: 0, bad: false, exifIfd: 0 };

      function walk(ifd, collectPointer) {
        if (ifd + 2 > out.length) {
          found.bad = true;
          return;
        }
        var n = dv.getUint16(ifd, le);
        for (var j = 0; j < n; j++) {
          var ent = ifd + 2 + j * 12;
          if (ent + 12 > out.length) {
            found.bad = true;
            return;
          }
          var tag = dv.getUint16(ent, le);
          if (collectPointer && tag === 0x8769) {
            found.exifIfd = hdr + dv.getUint32(ent + 8, le);
            continue;
          }
          if (tag !== 0xa002 && tag !== 0xa003) continue;
          var type = dv.getUint16(ent + 2, le);
          var value = tag === 0xa002 ? width : height;
          // SHORT (3) and LONG (4) are both small enough to sit inline in the
          // 4-byte value field, so nothing after this entry has to move.
          if (type === 3) dv.setUint16(ent + 8, value & 0xffff, le);
          else if (type === 4) dv.setUint32(ent + 8, value >>> 0, le);
          else continue; // an unexpected type is left exactly as found
          found.patched++;
        }
      }

      walk(ifd0, true);
      if (found.bad) return app1;
      if (found.exifIfd) {
        walk(found.exifIfd, false);
        if (found.bad) return app1;
      }
      return found.patched ? out : app1;
    } catch (err) {
      return app1; // never let metadata cosmetics break an export
    }
  }

  function spliceAPP1(jpegBytes, app1) {
    if (!app1) return jpegBytes;
    if (jpegBytes[0] !== 0xff || jpegBytes[1] !== 0xd8) return jpegBytes;
    var out = new Uint8Array(jpegBytes.length + app1.length);
    out.set(jpegBytes.subarray(0, 2), 0); // SOI
    out.set(app1, 2);
    out.set(jpegBytes.subarray(2), 2 + app1.length);
    return out;
  }

  // ------------------------------------------------------------------- ZIP
  //
  // Store-only (no deflate). JPEG and PNG are already compressed, so deflating
  // them buys nothing and would mean shipping an inflate/deflate implementation
  // for no gain.

  var CRC_TABLE = (function () {
    var t = new Uint32Array(256);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      t[n] = c >>> 0;
    }
    return t;
  })();

  function crc32(bytes) {
    var c = 0xffffffff;
    for (var i = 0; i < bytes.length; i++)
      c = CRC_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  }

  function dosTime(d) {
    return (
      ((d.getHours() << 11) | (d.getMinutes() << 5) | (d.getSeconds() / 2)) &
      0xffff
    );
  }
  function dosDate(d) {
    return (
      (((d.getFullYear() - 1980) << 9) |
        ((d.getMonth() + 1) << 5) |
        d.getDate()) &
      0xffff
    );
  }

  /** @param {{name: string, bytes: Uint8Array}[]} files */
  function makeZip(files) {
    var enc = new TextEncoder();
    var now = new Date();
    var time = dosTime(now);
    var date = dosDate(now);
    var chunks = [];
    var central = [];
    var offset = 0;

    files.forEach(function (f) {
      var nameBytes = enc.encode(f.name);
      var crc = crc32(f.bytes);
      var size = f.bytes.length;

      var local = new Uint8Array(30 + nameBytes.length);
      var lv = new DataView(local.buffer);
      lv.setUint32(0, 0x04034b50, true); // local file header
      lv.setUint16(4, 20, true); // version needed
      lv.setUint16(6, 0x0800, true); // UTF-8 filename flag
      lv.setUint16(8, 0, true); // stored
      lv.setUint16(10, time, true);
      lv.setUint16(12, date, true);
      lv.setUint32(14, crc, true);
      lv.setUint32(18, size, true);
      lv.setUint32(22, size, true);
      lv.setUint16(26, nameBytes.length, true);
      lv.setUint16(28, 0, true);
      local.set(nameBytes, 30);

      chunks.push(local, f.bytes);

      var cen = new Uint8Array(46 + nameBytes.length);
      var cv = new DataView(cen.buffer);
      cv.setUint32(0, 0x02014b50, true); // central directory header
      cv.setUint16(4, 20, true);
      cv.setUint16(6, 20, true);
      cv.setUint16(8, 0x0800, true);
      cv.setUint16(10, 0, true);
      cv.setUint16(12, time, true);
      cv.setUint16(14, date, true);
      cv.setUint32(16, crc, true);
      cv.setUint32(20, size, true);
      cv.setUint32(24, size, true);
      cv.setUint16(28, nameBytes.length, true);
      cv.setUint32(42, offset, true);
      cen.set(nameBytes, 46);
      central.push(cen);

      offset += local.length + size;
    });

    var centralSize = central.reduce(function (n, c) {
      return n + c.length;
    }, 0);

    var end = new Uint8Array(22);
    var ev = new DataView(end.buffer);
    ev.setUint32(0, 0x06054b50, true); // end of central directory
    ev.setUint16(8, files.length, true);
    ev.setUint16(10, files.length, true);
    ev.setUint32(12, centralSize, true);
    ev.setUint32(16, offset, true);

    return new Blob(chunks.concat(central, [end]), { type: "application/zip" });
  }

  // --------------------------------------------------------------- pipeline

  function saveBlob(blob, filename) {
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    // Give the browser a moment to start the download before dropping the URL.
    setTimeout(function () {
      URL.revokeObjectURL(url);
    }, 30000);
  }

  async function renderOneCanvas(bitmap, w, h, mime) {
    var canvas = document.createElement("canvas");
    canvas.width = w;
    canvas.height = h;
    var ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Could not get a 2D context");
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high"; // matches BitmapScalingMode.HighQuality
    ctx.drawImage(bitmap, 0, 0, w, h);

    var blob = await new Promise(function (resolve) {
      canvas.toBlob(
        resolve,
        mime,
        mime === "image/jpeg" ? JPEG_QUALITY : undefined,
      );
    });
    // Release the backing store immediately; 36 large canvases otherwise sit
    // in memory until GC decides otherwise.
    canvas.width = canvas.height = 0;
    if (!blob)
      throw new Error("Encoding failed — the image may exceed a browser limit");
    return blob;
  }

  async function processOne(item, mime) {
    var factor = item.factor || globalFactor;
    var bitmap = await createImageBitmap(item.file);
    try {
      var w = Math.round(bitmap.width * factor);
      var h = bitmap.height;
      var blob;
      item.note = null;

      if (fitsOneCanvas(w, h)) {
        blob = await renderOneCanvas(bitmap, w, h, mime);

        if (mime === "image/jpeg") {
          var srcBytes = new Uint8Array(await item.file.arrayBuffer());
          var app1 = findAPP1(srcBytes);
          if (app1) {
            var fixed = patchPixelDims(app1, w, h);
            var outBytes = spliceAPP1(
              new Uint8Array(await blob.arrayBuffer()),
              fixed,
            );
            blob = new Blob([outBytes], { type: "image/jpeg" });
          }
        }
      } else {
        // Over this browser's single-canvas limit. Render in tiles and write
        // the PNG ourselves; JPEG would need the canvas encoder we cannot have.
        // The APP1 TIFF block, dimensions corrected, rides along as eXIf.
        var src = new Uint8Array(await item.file.arrayBuffer());
        var a1 = findAPP1(src);
        var exif = a1 ? patchPixelDims(a1, w, h).subarray(10) : null;

        blob = await encodePNG(
          w,
          h,
          function (onRow) {
            return renderTiled(bitmap, w, h, factor, onRow);
          },
          exif,
        );
        if (mime === "image/jpeg")
          item.note =
            "Saved as PNG — " +
            fmtDims(w, h) +
            " is over this browser’s canvas limit, which JPEG encoding needs";
      }

      item.blob = blob;
      item.outW = w;
      item.outH = h;
      item.usedFactor = factor;
      item.state = "done";
      item.error = null;
      // Preview the real result, not the source. Without this the card shows
      // the squeezed original and there is no way to see what the tool did.
      revokeOut(item);
      item.outUrl = URL.createObjectURL(blob);
    } finally {
      bitmap.close();
    }
  }

  // ---------------------------------------------------------- canvas limits

  // Browsers cap canvases two ways, and the code used to guard only one.
  // Chrome and Firefox cap each side (16384 / 32767). Safari caps total AREA —
  // 4096² for years, 8192² since iOS 18 — which bites long before any side
  // reaches 16384: a 48MP frame widened 2× is 16000×6000, under the side limit
  // and well over Safari's area. A canvas over either limit does not throw; it
  // silently produces a blank bitmap. So the limits are measured, not assumed.
  var limits = null;

  function canvasWorks(w, h) {
    try {
      var c = document.createElement("canvas");
      c.width = w;
      c.height = h;
      var ctx = c.getContext("2d");
      if (!ctx) return false;
      ctx.fillStyle = "#fff";
      ctx.fillRect(w - 1, h - 1, 1, 1);
      var ok = ctx.getImageData(w - 1, h - 1, 1, 1).data[3] === 255;
      c.width = c.height = 0;
      return ok;
    } catch (e) {
      return false;
    }
  }

  function probeLimits() {
    if (limits) return limits;
    // Side limit: a 1-pixel-tall strip isolates it from the area limit.
    var dim = 4096;
    [8192, 16384].forEach(function (n) {
      if (canvasWorks(n, 1)) dim = n;
    });
    // Area limit. 8192² is Safari's post-iOS-18 ceiling and 268 MB of RGBA;
    // probing beyond it would risk the very out-of-memory this code exists to
    // avoid, and a 33 MP tile is already plenty. Below it, assume 4096².
    var area = 4096 * 4096;
    if (dim >= 8192 && canvasWorks(8192, 8192)) area = 8192 * 8192;
    limits = { maxDim: dim, maxArea: area };
    return limits;
  }

  /** True when the whole result fits in one canvas with room to spare. */
  function fitsOneCanvas(w, h) {
    var L = probeLimits();
    // Half the measured area: the probe only shows a canvas can exist, not
    // that it can exist beside the decoded source bitmap and the encoder.
    return w <= L.maxDim && h <= L.maxDim && w * h <= L.maxArea / 2;
  }

  // ------------------------------------------------------------ tiled path

  // For results no single canvas can hold: render in tiles, each inside the
  // measured limits, and stream the rows straight into a PNG encoder. The
  // output never exists as one canvas, so the only ceiling left is memory for
  // the encoded bytes.
  //
  // Tiles overlap by a few source pixels and the overlap is discarded, so the
  // resampler sees the same neighbourhood at a tile edge that it would see in
  // a single draw, and no seam is visible.
  var TILE_PAD = 4;

  async function renderTiled(bitmap, w, h, factor, onRow) {
    var L = probeLimits();
    var safeArea = L.maxArea / 2;
    var tileW = Math.min(w, L.maxDim);
    var bandH = Math.max(1, Math.min(h, L.maxDim, Math.floor(safeArea / tileW)));

    var tile = document.createElement("canvas");
    var ctx = tile.getContext("2d", { willReadFrequently: true });
    if (!ctx) throw new Error("Could not get a 2D context");
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";

    var rowBytes = w * 4;
    var band = new Uint8ClampedArray(rowBytes * bandH);

    for (var y0 = 0; y0 < h; y0 += bandH) {
      var bh = Math.min(bandH, h - y0);

      for (var x0 = 0; x0 < w; x0 += tileW) {
        var tw = Math.min(tileW, w - x0);
        // Pad the source rect so edge pixels resample against real neighbours.
        var padL = x0 === 0 ? 0 : TILE_PAD;
        var padR = x0 + tw >= w ? 0 : TILE_PAD;
        var dw = tw + padL + padR;
        var sx = (x0 - padL) / factor;
        var sw = dw / factor;

        tile.width = dw;
        tile.height = bh;
        ctx.clearRect(0, 0, dw, bh);
        ctx.drawImage(bitmap, sx, y0, sw, bh, 0, 0, dw, bh);

        var px = ctx.getImageData(padL, 0, tw, bh).data;
        for (var r = 0; r < bh; r++) {
          band.set(
            px.subarray(r * tw * 4, (r + 1) * tw * 4),
            r * rowBytes + x0 * 4,
          );
        }
      }

      for (var row = 0; row < bh; row++) {
        await onRow(band.subarray(row * rowBytes, (row + 1) * rowBytes));
      }
      await breathe();
    }

    tile.width = tile.height = 0;
  }

  // ----------------------------------------------------------- PNG writer

  // A streaming PNG encoder. IDAT is a zlib stream, which is exactly what
  // CompressionStream("deflate") produces, so the browser does the heavy
  // lifting natively and nothing here depends on a library. Rows arrive one at
  // a time from the tiled renderer and go straight through the compressor;
  // the uncompressed image is never held whole.
  function pngChunk(type, data) {
    var out = new Uint8Array(12 + data.length);
    var v = new DataView(out.buffer);
    v.setUint32(0, data.length);
    for (var i = 0; i < 4; i++) out[4 + i] = type.charCodeAt(i);
    out.set(data, 8);
    v.setUint32(8 + data.length, crc32(out.subarray(4, 8 + data.length)));
    return out;
  }

  /**
   * @param {number} w
   * @param {number} h
   * @param {(onRow: (row: Uint8ClampedArray) => Promise<void>) => Promise<void>} produceRows
   * @param {Uint8Array|null} exif  TIFF payload for an eXIf chunk, or null
   */
  async function encodePNG(w, h, produceRows, exif) {
    var parts = [new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10])];

    var ihdr = new Uint8Array(13);
    var iv = new DataView(ihdr.buffer);
    iv.setUint32(0, w);
    iv.setUint32(4, h);
    ihdr[8] = 8; // bit depth
    ihdr[9] = 6; // colour type: RGBA
    parts.push(pngChunk("IHDR", ihdr));

    // eXIf (PNG 1.5 / ISO 15948:2022) carries the same TIFF block that JPEG's
    // APP1 does, so metadata survives the format change.
    if (exif && exif.length) parts.push(pngChunk("eXIf", exif));

    var cs = new CompressionStream("deflate");
    var writer = cs.writable.getWriter();
    var compressed = [];
    var reading = (async function () {
      var reader = cs.readable.getReader();
      for (;;) {
        var r = await reader.read();
        if (r.done) break;
        compressed.push(r.value);
      }
    })();

    var filtered = new Uint8Array(1 + w * 4);
    filtered[0] = 0; // filter type: none, per scanline
    await produceRows(async function (row) {
      filtered.set(row, 1);
      await writer.write(filtered.slice());
    });
    await writer.close();
    await reading;

    var total = compressed.reduce(function (n, c) {
      return n + c.length;
    }, 0);
    var idat = new Uint8Array(total);
    var off = 0;
    compressed.forEach(function (c) {
      idat.set(c, off);
      off += c.length;
    });
    parts.push(pngChunk("IDAT", idat));
    parts.push(pngChunk("IEND", new Uint8Array(0)));

    return new Blob(parts, { type: "image/png" });
  }

  // ----------------------------------------------------------------- render

  function render() {
    var grid = $("grid");
    grid.textContent = "";

    items.forEach(function (item) {
      var li = document.createElement("li");
      li.className = "card";

      var thumb = document.createElement("div");
      thumb.className = "thumb";
      if (item.outUrl || item.url) {
        var img = document.createElement("img");
        img.alt = "";
        if (item.outUrl) {
          // Finished: this file is already the right shape, so let it be.
          img.src = item.outUrl;
          img.style.objectFit = "contain";
        } else {
          // Pending: stretch the source into a box of the target aspect, which
          // is exactly the correction about to be applied. `fill` is the point
          // here — `contain` would letterbox and show no change at all.
          var f = item.factor || globalFactor;
          img.src = item.url;
          img.style.aspectRatio = item.w * f + " / " + item.h;
          img.style.width = "100%";
          img.style.objectFit = "fill";
        }
        thumb.appendChild(img);
      }
      li.appendChild(thumb);

      var body = document.createElement("div");
      body.className = "card-body";

      var name = document.createElement("p");
      name.className = "name";
      name.textContent = item.name;
      body.appendChild(name);

      var dims = document.createElement("p");
      dims.className = "dims";
      if (item.state === "done") {
        dims.innerHTML = "";
        dims.appendChild(
          document.createTextNode(fmtDims(item.w, item.h) + "  →  "),
        );
        var out = document.createElement("span");
        out.className = "out";
        out.textContent =
          fmtDims(item.outW, item.outH) + "  " + ratio(item.outW, item.outH);
        dims.appendChild(out);
      } else {
        dims.textContent =
          fmtDims(item.w, item.h) + "  " + ratio(item.w, item.h);
      }
      body.appendChild(dims);

      var foot = document.createElement("div");
      foot.className = "card-foot";

      // Per-image override, as the native batch mode offers.
      var sel = document.createElement("select");
      sel.setAttribute("aria-label", "Factor for " + item.name);
      var optDefault = document.createElement("option");
      optDefault.value = "";
      optDefault.textContent = "Batch";
      sel.appendChild(optDefault);
      PRESETS.forEach(function (p) {
        var o = document.createElement("option");
        o.value = String(p.factor);
        o.textContent = p.label;
        sel.appendChild(o);
      });
      sel.value = item.factor ? String(item.factor) : "";
      sel.addEventListener("change", function () {
        item.factor = sel.value ? parseFloat(sel.value) : null;
        if (item.state === "done") {
          item.state = "ready";
          item.blob = null;
          revokeOut(item);
        }
        render();
        refreshControls();
      });
      foot.appendChild(sel);

      if (item.state === "done") {
        var dl = document.createElement("button");
        dl.type = "button";
        dl.className = "dl";
        dl.textContent = "Download";
        dl.addEventListener("click", function () {
          saveBlob(
            item.blob,
            outName(item.name, item.usedFactor, item.blob.type),
          );
        });
        foot.appendChild(dl);
      } else {
        var state = document.createElement("span");
        state.className = "state" + (item.state === "error" ? " error" : "");
        state.textContent =
          item.state === "error"
            ? "Failed"
            : item.state === "working"
              ? "Working…"
              : "Ready";
        state.title = item.error || "";
        foot.appendChild(state);
      }

      var rm = document.createElement("button");
      rm.type = "button";
      rm.className = "remove";
      rm.setAttribute("aria-label", "Remove " + item.name);
      rm.textContent = "×";
      rm.addEventListener("click", function () {
        revoke(item);
        items = items.filter(function (x) {
          return x.id !== item.id;
        });
        render();
        refreshControls();
      });
      foot.appendChild(rm);

      body.appendChild(foot);

      if (item.state === "error" && item.error) {
        var err = document.createElement("p");
        err.className = "dims";
        err.style.color = "var(--safelight)";
        err.textContent = item.error;
        body.appendChild(err);
      }

      if (item.state === "done" && item.note) {
        var note = document.createElement("p");
        note.className = "dims";
        note.textContent = item.note;
        body.appendChild(note);
      }

      li.appendChild(body);
      grid.appendChild(li);
    });
  }

  function refreshControls() {
    var has = items.length > 0;
    $("controls").classList.toggle("hidden", !has);
    $("run-section").classList.toggle("hidden", !has);
    var done = items.filter(function (i) {
      return i.state === "done";
    });
    $("download-all").disabled = done.length === 0 || running;
    $("run").disabled = running || items.length === 0;
    $("download-all").textContent =
      done.length > 1
        ? "Download all (" + done.length + ") .zip"
        : "Download all (.zip)";
  }

  // ------------------------------------------------------------------ input

  async function addFiles(fileList) {
    var incoming = Array.prototype.slice.call(fileList).filter(function (f) {
      return (
        f.type.indexOf("image/") === 0 ||
        /\.(hei[cf]|avif|jpe?g|png|webp)$/i.test(f.name)
      );
    });

    var msgEl = $("add-msg");
    if (incoming.length === 0) {
      setMsg(msgEl, "No images in that selection.", true);
      return;
    }

    var room = MAX_FILES - items.length;
    var rejected = 0;
    if (incoming.length > room) {
      rejected = incoming.length - room;
      incoming = incoming.slice(0, Math.max(0, room));
    }

    for (var i = 0; i < incoming.length; i++) {
      var file = incoming[i];
      var item = {
        id: nextId++,
        file: file,
        name: file.name,
        w: 0,
        h: 0,
        factor: null,
        blob: null,
        url: null,
        state: "ready",
        error: null,
      };
      try {
        var bmp = await createImageBitmap(file);
        item.w = bmp.width;
        item.h = bmp.height;
        bmp.close();
        item.url = URL.createObjectURL(file);
        items.push(item);
      } catch (e) {
        item.state = "error";
        item.error = "Could not read this file";
        items.push(item);
      }
    }

    if (rejected > 0) {
      setMsg(
        msgEl,
        "Added " +
          incoming.length +
          ". " +
          rejected +
          " not added — " +
          MAX_FILES +
          " images is the limit.",
        true,
      );
    } else {
      setMsg(msgEl, items.length + " of " + MAX_FILES + " loaded.", false);
    }

    render();
    refreshControls();
  }

  // -------------------------------------------------------------------- run

  async function runAll() {
    if (running) return;
    running = true;
    refreshControls();

    var mime = $("fmt").value;
    var pending = items.filter(function (i) {
      return i.state !== "done" && i.state !== "error";
    });
    var failures = 0;

    for (var i = 0; i < pending.length; i++) {
      var item = pending[i];
      item.state = "working";
      render();
      setMsg(
        $("progress"),
        "Desqueezing " + (i + 1) + " of " + pending.length + "…",
        false,
      );
      await breathe();
      try {
        await processOne(item, mime);
      } catch (e) {
        item.state = "error";
        item.error = e && e.message ? e.message : "Failed";
        failures++;
      }
      render();
      refreshControls();
    }

    running = false;
    var done = items.filter(function (i) {
      return i.state === "done";
    }).length;
    setMsg(
      $("progress"),
      failures
        ? done + " done, " + failures + " failed — see the cards below."
        : done + " image" + (done === 1 ? "" : "s") + " desqueezed.",
      failures > 0,
    );
    refreshControls();
  }

  async function downloadAll() {
    var done = items.filter(function (i) {
      return i.state === "done";
    });
    if (done.length === 0) return;
    if (done.length === 1) {
      saveBlob(
        done[0].blob,
        outName(done[0].name, done[0].usedFactor, done[0].blob.type),
      );
      return;
    }
    setMsg($("progress"), "Packing " + done.length + " images…", false);
    await breathe();

    var used = Object.create(null);
    var files = [];
    for (var i = 0; i < done.length; i++) {
      var item = done[i];
      var name = outName(item.name, item.usedFactor, item.blob.type);
      // Two sources can share a filename; a zip with duplicates is a bad zip.
      if (used[name]) {
        var dot = name.lastIndexOf(".");
        name = name.slice(0, dot) + "_" + used[name] + name.slice(dot);
      }
      used[name] = (used[name] || 0) + 1;
      files.push({
        name: name,
        bytes: new Uint8Array(await item.blob.arrayBuffer()),
      });
    }

    saveBlob(makeZip(files), "desqueezed.zip");
    setMsg($("progress"), done.length + " images packed.", false);
  }

  function clearAll() {
    items.forEach(revoke);
    items = [];
    render();
    refreshControls();
    setMsg($("add-msg"), "", false);
    setMsg($("progress"), "", false);
    $("file-input").value = "";
  }

  // ------------------------------------------------------------------- init

  function buildPresets() {
    var box = $("presets");
    PRESETS.forEach(function (p) {
      var b = document.createElement("button");
      b.type = "button";
      b.className = "preset";
      b.setAttribute("role", "radio");
      b.setAttribute("aria-checked", String(p.factor === globalFactor));
      b.dataset.factor = String(p.factor);
      b.appendChild(document.createTextNode(p.label));
      var g = document.createElement("span");
      g.className = "glass";
      g.textContent = p.glass;
      b.appendChild(g);
      b.addEventListener("click", function () {
        globalFactor = p.factor;
        $("custom-factor").value = "";
        syncPresets();
        invalidateDone();
      });
      box.appendChild(b);
    });
  }

  function syncPresets() {
    var buttons = $("presets").querySelectorAll(".preset");
    Array.prototype.forEach.call(buttons, function (b) {
      b.setAttribute(
        "aria-checked",
        String(parseFloat(b.dataset.factor) === globalFactor),
      );
    });
  }

  /** A factor change makes any finished result stale — say so rather than
   *  letting someone download a file that no longer matches the control. */
  function invalidateDone() {
    var changed = false;
    items.forEach(function (i) {
      if (i.state === "done" && !i.factor) {
        i.state = "ready";
        i.blob = null;
        revokeOut(i);
        changed = true;
      }
    });
    if (changed) setMsg($("progress"), "Factor changed — run again.", false);
    render();
    refreshControls();
  }

  function init() {
    buildPresets();

    var drop = $("drop");
    var input = $("file-input");

    drop.addEventListener("click", function () {
      input.click();
    });
    drop.addEventListener("keydown", function (e) {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        input.click();
      }
    });
    input.addEventListener("change", function () {
      addFiles(input.files);
      input.value = ""; // so re-picking the same file fires change again
    });

    ["dragenter", "dragover"].forEach(function (ev) {
      drop.addEventListener(ev, function (e) {
        e.preventDefault();
        drop.classList.add("over");
      });
    });
    ["dragleave", "drop"].forEach(function (ev) {
      drop.addEventListener(ev, function (e) {
        e.preventDefault();
        if (ev === "dragleave" && drop.contains(e.relatedTarget)) return;
        drop.classList.remove("over");
      });
    });
    drop.addEventListener("drop", function (e) {
      if (e.dataTransfer && e.dataTransfer.files)
        addFiles(e.dataTransfer.files);
    });
    // A file dropped anywhere else would otherwise navigate away from the app,
    // losing the queue.
    window.addEventListener("dragover", function (e) {
      e.preventDefault();
    });
    window.addEventListener("drop", function (e) {
      e.preventDefault();
    });

    $("custom-factor").addEventListener("input", function (e) {
      var v = parseFloat(e.target.value);
      if (!isNaN(v) && v >= 1.01 && v <= 3) {
        globalFactor = v;
        syncPresets();
        invalidateDone();
      }
    });

    $("fmt").addEventListener("change", function () {
      $("exif-note").textContent =
        $("fmt").value === "image/jpeg"
          ? "EXIF Data, including capture date, camera, lens, is passed non destructively to output files."
          : "PNG output carries no EXIF. Choose JPEG to keep capture metadata.";
      invalidateDone();
    });

    $("run").addEventListener("click", runAll);
    $("download-all").addEventListener("click", downloadAll);
    $("clear").addEventListener("click", clearAll);

    // Nothing survives the tab, by design.
    window.addEventListener("pagehide", function () {
      items.forEach(revoke);
    });

    refreshControls();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
