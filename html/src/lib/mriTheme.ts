import type { CSSProperties } from 'react'

export interface UiTheme {
  name?: string
  colors: {
    background: string
    card: string
    border: string
    text: {
      primary: string
      secondary: string
      muted: string
    }
    accent: {
      primary: string
      secondary: string
      success: string
      danger: string
    }
    button?: {
      primary: string
      primaryHover: string
      danger: string
      dangerHover: string
    }
  }
}

type RgbColor = {
  r: number
  g: number
  b: number
  a: number
}

const DEFAULT_FALLBACKS = {
  background: 'rgb(9, 9, 11)',
  card: 'rgb(18, 18, 22)',
  border: 'rgb(39, 39, 42)',
  textPrimary: 'rgb(255, 255, 255)',
  textSecondary: 'rgb(161, 161, 170)',
  textMuted: 'rgb(113, 113, 122)',
  accentPrimary: 'rgb(0, 255, 163)',
  accentSecondary: 'rgb(0, 209, 134)',
  accentDanger: 'rgb(255, 59, 59)',
} as const

function clamp(value: number, min = 0, max = 255) {
  return Math.min(Math.max(value, min), max)
}

function parseHexColor(color: string): RgbColor | null {
  const value = color.replace('#', '').trim()

  if (![3, 4, 6, 8].includes(value.length)) {
    return null
  }

  const expanded = value.length <= 4
    ? value.split('').map((char) => char + char).join('')
    : value

  const hasAlpha = expanded.length === 8
  const r = Number.parseInt(expanded.slice(0, 2), 16)
  const g = Number.parseInt(expanded.slice(2, 4), 16)
  const b = Number.parseInt(expanded.slice(4, 6), 16)
  const a = hasAlpha ? Number.parseInt(expanded.slice(6, 8), 16) / 255 : 1

  if ([r, g, b].some((channel) => Number.isNaN(channel)) || Number.isNaN(a)) {
    return null
  }

  return { r, g, b, a }
}

function parseRgbColor(color: string): RgbColor | null {
  const match = color.match(/rgba?\(([^)]+)\)/i)
  if (!match) {
    return null
  }

  const parts = match[1].split(',').map((part) => part.trim())
  if (parts.length < 3) {
    return null
  }

  const r = Number.parseFloat(parts[0])
  const g = Number.parseFloat(parts[1])
  const b = Number.parseFloat(parts[2])
  const a = parts[3] !== undefined ? Number.parseFloat(parts[3]) : 1

  if ([r, g, b, a].some((channel) => Number.isNaN(channel))) {
    return null
  }

  return { r, g, b, a }
}

function parseColor(color?: string, fallback: string = DEFAULT_FALLBACKS.card): RgbColor {
  if (!color) {
    return parseColor(fallback, DEFAULT_FALLBACKS.card)
  }

  const normalized = color.trim()

  if (normalized.startsWith('#')) {
    return parseHexColor(normalized) ?? parseColor(fallback, DEFAULT_FALLBACKS.card)
  }

  if (normalized.startsWith('rgb')) {
    return parseRgbColor(normalized) ?? parseColor(fallback, DEFAULT_FALLBACKS.card)
  }

  return parseColor(fallback, DEFAULT_FALLBACKS.card)
}

function rgbToHslTriplet({ r, g, b }: RgbColor) {
  const red = clamp(r) / 255
  const green = clamp(g) / 255
  const blue = clamp(b) / 255

  const max = Math.max(red, green, blue)
  const min = Math.min(red, green, blue)
  const lightness = (max + min) / 2

  if (max === min) {
    return `0 0% ${Math.round(lightness * 100)}%`
  }

  const delta = max - min
  const saturation = lightness > 0.5
    ? delta / (2 - max - min)
    : delta / (max + min)

  let hue = 0

  switch (max) {
    case red:
      hue = (green - blue) / delta + (green < blue ? 6 : 0)
      break
    case green:
      hue = (blue - red) / delta + 2
      break
    default:
      hue = (red - green) / delta + 4
      break
  }

  hue /= 6

  return `${Math.round(hue * 360)} ${Math.round(saturation * 100)}% ${Math.round(lightness * 100)}%`
}

function toRgbaString(color?: string, alpha = 1, fallback?: string) {
  const parsed = parseColor(color, fallback)
  const safeAlpha = Math.min(Math.max(alpha, 0), 1)
  return `rgba(${parsed.r}, ${parsed.g}, ${parsed.b}, ${safeAlpha})`
}

function toSolidRgb(color?: string, fallback?: string) {
  const parsed = parseColor(color, fallback)
  return `rgb(${parsed.r}, ${parsed.g}, ${parsed.b})`
}

function getReadableForeground(color?: string, lightFallback = 'rgb(255, 255, 255)', darkFallback = 'rgb(9, 9, 11)') {
  const parsed = parseColor(color, DEFAULT_FALLBACKS.accentPrimary)
  const luminance = (0.299 * parsed.r + 0.587 * parsed.g + 0.114 * parsed.b) / 255

  return luminance > 0.65 ? darkFallback : lightFallback
}

function toCssVariableValue(color: string | undefined, fallback: string) {
  const parsed = parseColor(color, fallback)
  // Forçar o canal alfa para 1 (sólido) antes de converter para HSL
  return rgbToHslTriplet({ ...parsed, a: 1 })
}

export function getMriThemeVars(theme: UiTheme | null | undefined): CSSProperties {
  const colors = theme?.colors
  const primaryForeground = getReadableForeground(colors?.accent?.primary)
  const destructiveForeground = getReadableForeground(colors?.accent?.danger, 'rgb(255, 255, 255)', 'rgb(255, 255, 255)')

  return {
    '--background': '240 10% 4%',
    '--card': '240 10% 4%',
    ['--foreground' as string]: toCssVariableValue(colors?.text?.primary, DEFAULT_FALLBACKS.textPrimary),
    ['--card-foreground' as string]: toCssVariableValue(colors?.text?.primary, DEFAULT_FALLBACKS.textPrimary),
    ['--popover' as string]: toCssVariableValue(colors?.card, DEFAULT_FALLBACKS.card),
    ['--popover-foreground' as string]: toCssVariableValue(colors?.text?.primary, DEFAULT_FALLBACKS.textPrimary),
    ['--primary' as string]: toCssVariableValue(colors?.accent?.primary, DEFAULT_FALLBACKS.accentPrimary),
    ['--primary-foreground' as string]: toCssVariableValue(primaryForeground, 'rgb(9, 9, 11)'),
    ['--secondary' as string]: toCssVariableValue(colors?.card, DEFAULT_FALLBACKS.card),
    ['--secondary-foreground' as string]: toCssVariableValue(colors?.text?.primary, DEFAULT_FALLBACKS.textPrimary),
    ['--muted' as string]: toCssVariableValue(colors?.border, DEFAULT_FALLBACKS.border),
    ['--muted-foreground' as string]: toCssVariableValue(colors?.text?.muted, DEFAULT_FALLBACKS.textMuted),
    ['--accent' as string]: toCssVariableValue(colors?.accent?.secondary || colors?.accent?.primary, DEFAULT_FALLBACKS.accentSecondary),
    ['--accent-foreground' as string]: toCssVariableValue(colors?.text?.primary, DEFAULT_FALLBACKS.textPrimary),
    ['--destructive' as string]: toCssVariableValue(colors?.accent?.danger, DEFAULT_FALLBACKS.accentDanger),
    ['--destructive-foreground' as string]: toCssVariableValue(destructiveForeground, DEFAULT_FALLBACKS.textPrimary),
    ['--border' as string]: toCssVariableValue(colors?.border, DEFAULT_FALLBACKS.border),
    ['--input' as string]: toCssVariableValue(colors?.border, DEFAULT_FALLBACKS.border),
    ['--ring' as string]: toCssVariableValue(colors?.accent?.primary, DEFAULT_FALLBACKS.accentPrimary),
    ['--radius' as string]: '1rem',
  } as CSSProperties
}

export function alphaColor(color?: string, alpha = 1, fallback?: string) {
  return toRgbaString(color, alpha, fallback)
}

export function solidColor(color?: string, fallback?: string) {
  return toSolidRgb(color, fallback)
}
