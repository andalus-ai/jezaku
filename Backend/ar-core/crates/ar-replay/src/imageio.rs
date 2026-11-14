//! Minimal grayscale image I/O: PGM (P5) and PNG (8/16-bit gray, RGB(A) -> luma).
use std::fs::File;
use std::io::{BufWriter, Read};
use std::path::Path;

pub struct GrayImage { pub w: usize, pub h: usize, pub data: Vec<u8> }

pub fn load_gray(path: &Path) -> Result<GrayImage, String> {
    let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("").to_ascii_lowercase();
    match ext.as_str() {
        "pgm" => load_pgm(path),
        "png" => load_png(path),
        other => Err(format!("{}: unsupported image extension '{other}' (use .png or .pgm)", path.display())),
    }
}

fn load_pgm(path: &Path) -> Result<GrayImage, String> {
    let mut bytes = vec![];
    File::open(path).and_then(|mut f| f.read_to_end(&mut bytes)).map_err(|e| format!("{}: {e}", path.display()))?;
    let mut pos = 0usize;
    let mut token = |bytes: &[u8]| -> Option<String> {
        while pos < bytes.len() {
            if bytes[pos] == b'#' { while pos < bytes.len() && bytes[pos] != b'\n' { pos += 1; } }
            else if bytes[pos].is_ascii_whitespace() { pos += 1 } else { break }
        }
        let start = pos;
        while pos < bytes.len() && !bytes[pos].is_ascii_whitespace() { pos += 1; }
        (pos > start).then(|| String::from_utf8_lossy(&bytes[start..pos]).into_owned())
    };
    let bad = || format!("{}: malformed PGM header", path.display());
    if token(&bytes).as_deref() != Some("P5") { return Err(format!("{}: not a binary PGM (P5)", path.display())); }
    let w: usize = token(&bytes).and_then(|t| t.parse().ok()).ok_or_else(bad)?;
    let h: usize = token(&bytes).and_then(|t| t.parse().ok()).ok_or_else(bad)?;
    let maxv: usize = token(&bytes).and_then(|t| t.parse().ok()).ok_or_else(bad)?;
    pos += 1; // exactly one whitespace byte separates header and data
    let bpp = if maxv < 256 { 1 } else { 2 };
    let need = w * h * bpp;
    if w == 0 || h == 0 || bytes.len() < pos + need { return Err(format!("{}: truncated PGM data", path.display())); }
    let data = if bpp == 1 { bytes[pos..pos + need].to_vec() } else { bytes[pos..pos + need].chunks(2).map(|c| c[0]).collect() };
    Ok(GrayImage { w, h, data })
}

fn load_png(path: &Path) -> Result<GrayImage, String> {
    let err = |e: &dyn std::fmt::Display| format!("{}: {e}", path.display());
    let file = File::open(path).map_err(|e| err(&e))?;
    let mut dec = png::Decoder::new(file);
    dec.set_transformations(png::Transformations::EXPAND);
    let mut reader = dec.read_info().map_err(|e| err(&e))?;
    let mut buf = vec![0; reader.output_buffer_size()];
    let info = reader.next_frame(&mut buf).map_err(|e| err(&e))?;
    let raw = &buf[..info.buffer_size()];
    let (w, h) = (info.width as usize, info.height as usize);
    let step = if info.bit_depth == png::BitDepth::Sixteen { 2 } else { 1 }; // keep the high byte of 16-bit samples
    let ch = match info.color_type { png::ColorType::Grayscale => 1, png::ColorType::GrayscaleAlpha => 2, png::ColorType::Rgb => 3, png::ColorType::Rgba => 4, png::ColorType::Indexed => return Err(err(&"indexed PNG not expanded")) };
    let px = ch * step;
    if raw.len() < w * h * px { return Err(err(&"decoded buffer too small")); }
    let sample = |i: usize, c: usize| raw[i * px + c * step] as u32;
    let data = (0..w * h).map(|i| match ch {
        1 | 2 => sample(i, 0) as u8,
        _ => ((299 * sample(i, 0) + 587 * sample(i, 1) + 114 * sample(i, 2)) / 1000) as u8,
    }).collect();
    Ok(GrayImage { w, h, data })
}

pub fn write_pgm(path: &Path, w: usize, h: usize, data: &[u8]) -> Result<(), String> {
    use std::io::Write;
    let mut f = BufWriter::new(File::create(path).map_err(|e| format!("{}: {e}", path.display()))?);
    write!(f, "P5\n{w} {h}\n255\n").and_then(|_| f.write_all(data)).map_err(|e| e.to_string())
}

pub fn write_png_gray(path: &Path, w: usize, h: usize, data: &[u8]) -> Result<(), String> {
    let f = BufWriter::new(File::create(path).map_err(|e| format!("{}: {e}", path.display()))?);
    let mut enc = png::Encoder::new(f, w as u32, h as u32);
    enc.set_color(png::ColorType::Grayscale);
    enc.set_depth(png::BitDepth::Eight);
    enc.write_header().and_then(|mut w| w.write_image_data(data)).map_err(|e| e.to_string())
}
