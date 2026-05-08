// Aplica `accentColor` (hex #RRGGBB ou #RRGGBBAA) na CSS var --primary
// que alimenta bg-primary, text-primary, border-primary, hsl(var(--primary)/X)
// para shadows e glows. Alpha do hex é ignorado para o token HSL.
//
// Mesmo padrão que o `mri_Qspawn` — convar `mri:color` propaga visual da suite.
export function applyAccentColor(hex: string) {
  const m = hex.match(/^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})?$/i)
  if (!m) return

  const r = parseInt(m[1], 16) / 255
  const g = parseInt(m[2], 16) / 255
  const b = parseInt(m[3], 16) / 255

  const max = Math.max(r, g, b)
  const min = Math.min(r, g, b)
  const l = (max + min) / 2

  let h = 0
  let s = 0
  if (max !== min) {
    const d = max - min
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    if (max === r) h = ((g - b) / d + (g < b ? 6 : 0))
    else if (max === g) h = ((b - r) / d + 2)
    else h = ((r - g) / d + 4)
    h *= 60
  }

  document.documentElement.style.setProperty(
    '--primary',
    `${Math.round(h)} ${Math.round(s * 100)}% ${Math.round(l * 100)}%`,
  )
  document.documentElement.style.setProperty(
    '--ring',
    `${Math.round(h)} ${Math.round(s * 100)}% ${Math.round(l * 100)}%`,
  )
}

export function isValidHex(value: string): boolean {
  return /^#[0-9a-f]{6}$/i.test(value)
}
