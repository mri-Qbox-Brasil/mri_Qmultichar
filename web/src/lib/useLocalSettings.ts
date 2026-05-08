import { useCallback, useEffect, useState } from 'react'

const STORAGE_PREFIX = 'mri_Qmultichar:'

export interface LocalSettings {
  streamerMode: boolean
  cameraEffects: boolean
  cameraEffectType: string
  // null = sem override; usa a cor vinda do servidor (convar/Config).
  accentColorOverride: string | null
}

export interface SettingsDefaults {
  streamerMode?: boolean
  cameraEffects?: boolean
  cameraEffectType?: string
}

function readBoolean(key: string, fallback: boolean): boolean {
  const raw = localStorage.getItem(STORAGE_PREFIX + key)
  if (raw === null) return fallback
  return raw === 'true'
}

function readString(key: string, fallback: string): string {
  const raw = localStorage.getItem(STORAGE_PREFIX + key)
  return raw ?? fallback
}

function readNullableString(key: string): string | null {
  return localStorage.getItem(STORAGE_PREFIX + key)
}

export function useLocalSettings(defaults: SettingsDefaults = {}) {
  const [settings, setSettings] = useState<LocalSettings>(() => ({
    streamerMode: readBoolean('streamerMode', defaults.streamerMode ?? false),
    cameraEffects: readBoolean('cameraEffects', defaults.cameraEffects ?? true),
    cameraEffectType: readString('cameraEffectType', defaults.cameraEffectType ?? 'cinema'),
    accentColorOverride: readNullableString('accentColor'),
  }))

  // Reaplica defaults se o servidor mandar valores novos e o usuário ainda
  // não tem override em localStorage.
  useEffect(() => {
    setSettings((prev) => ({
      streamerMode: localStorage.getItem(STORAGE_PREFIX + 'streamerMode') === null
        ? defaults.streamerMode ?? prev.streamerMode
        : prev.streamerMode,
      cameraEffects: localStorage.getItem(STORAGE_PREFIX + 'cameraEffects') === null
        ? defaults.cameraEffects ?? prev.cameraEffects
        : prev.cameraEffects,
      cameraEffectType: localStorage.getItem(STORAGE_PREFIX + 'cameraEffectType') === null
        ? defaults.cameraEffectType ?? prev.cameraEffectType
        : prev.cameraEffectType,
      accentColorOverride: prev.accentColorOverride,
    }))
  }, [defaults.streamerMode, defaults.cameraEffects, defaults.cameraEffectType])

  const setStreamerMode = useCallback((value: boolean) => {
    localStorage.setItem(STORAGE_PREFIX + 'streamerMode', String(value))
    setSettings((prev) => ({ ...prev, streamerMode: value }))
  }, [])

  const setCameraEffects = useCallback((value: boolean) => {
    localStorage.setItem(STORAGE_PREFIX + 'cameraEffects', String(value))
    setSettings((prev) => ({ ...prev, cameraEffects: value }))
  }, [])

  const setCameraEffectType = useCallback((value: string) => {
    localStorage.setItem(STORAGE_PREFIX + 'cameraEffectType', value)
    setSettings((prev) => ({ ...prev, cameraEffectType: value }))
  }, [])

  const setAccentColorOverride = useCallback((value: string | null) => {
    if (value === null) {
      localStorage.removeItem(STORAGE_PREFIX + 'accentColor')
    } else {
      localStorage.setItem(STORAGE_PREFIX + 'accentColor', value)
    }
    setSettings((prev) => ({ ...prev, accentColorOverride: value }))
  }, [])

  return {
    settings,
    setStreamerMode,
    setCameraEffects,
    setCameraEffectType,
    setAccentColorOverride,
  }
}
