import { useState, useEffect } from 'react'
import { Settings, Camera, Music, Music2, Palette, EyeOff, X } from 'lucide-react'
import { cn } from '@/lib/utils'

declare function GetParentResourceName(): string

interface Theme {
  name: string
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
  }
}

interface SettingsPanelProps {
  theme: Theme | null
  availableThemes: { [key: string]: Theme }
  onClose: () => void
  onThemeChange?: (themeName: string) => void
  allowThemeChange?: boolean
}

export function SettingsPanel({ 
  theme, 
  availableThemes, 
  onClose,
  onThemeChange,
  allowThemeChange = true
}: SettingsPanelProps) {
  const [cameraEffects, setCameraEffects] = useState(true)
  const [cameraEffectType, setCameraEffectType] = useState('cinema')
  const [streamerMode, setStreamerMode] = useState(false)
  const [selectedTheme, setSelectedTheme] = useState(theme?.name || 'dark')

  // Opções de efeitos de câmera
  const cameraEffectsOptions = [
    { value: 'default', label: 'Normal', icon: '🎬' },
    { value: 'cinema', label: 'Cinema', icon: '🎥' },
    { value: 'grayscale', label: 'Preto e Branco', icon: '⚫' },
    { value: 'sepia', label: 'Sépia', icon: '📸' },
    { value: 'vintage', label: 'Vintage', icon: '📷' },
    { value: 'dream', label: 'Sonho', icon: '✨' },
    { value: 'nightvision', label: 'Visão Noturna', icon: '🌙' },
  ]

  // Carregar configurações ao montar
  useEffect(() => {
    const loadSettings = async () => {
      try {
        const response = await fetch(`https://${GetParentResourceName()}/getSettings`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
        })
        const data = await response.json()
        if (data.success) {
          if (data.settings.cameraEffects !== undefined) {
            setCameraEffects(data.settings.cameraEffects)
          }
          if (data.settings.cameraEffectType) {
            setCameraEffectType(data.settings.cameraEffectType)
          }
          if (data.settings.streamerMode !== undefined) {
            setStreamerMode(data.settings.streamerMode)
          }
          if (data.settings.theme) {
            setSelectedTheme(data.settings.theme)
          }
        }
      } catch (error) {
        console.error('Erro ao carregar configurações:', error)
      }
    }
    loadSettings()
  }, [])

  const handleThemeChange = (themeName: string) => {
    if (!allowThemeChange) return
    setSelectedTheme(themeName)
    if (onThemeChange) {
      onThemeChange(themeName)
    }
    // Enviar para o servidor
    fetch(`https://${GetParentResourceName()}/updateSettings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        theme: themeName,
        cameraEffects,
        streamerMode
      }),
    }).catch(console.error)
  }

  const handleCameraEffects = (enabled: boolean) => {
    setCameraEffects(enabled)
    fetch(`https://${GetParentResourceName()}/updateSettings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        theme: selectedTheme,
        cameraEffects: enabled,
        cameraEffectType: enabled ? cameraEffectType : 'default',
        streamerMode
      }),
    }).catch(console.error)
  }

  const handleCameraEffectType = (effectType: string) => {
    setCameraEffectType(effectType)
    fetch(`https://${GetParentResourceName()}/updateSettings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        theme: selectedTheme,
        cameraEffects: true,
        cameraEffectType: effectType,
        streamerMode
      }),
    }).catch(console.error)
  }

  const handleStreamerMode = (enabled: boolean) => {
    setStreamerMode(enabled)
    fetch(`https://${GetParentResourceName()}/updateSettings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        theme: selectedTheme,
        cameraEffects,
        streamerMode: enabled
      }),
    }).catch(console.error)
  }

  return (
    <>
      {/* Overlay de fundo */}
      <div
        onClick={onClose}
        className="fixed inset-0"
        style={{
          backgroundColor: 'rgba(0, 0, 0, 0.3)',
          pointerEvents: 'auto',
          zIndex: 99998,
        }}
      />
      <div 
        className={cn(
          "fixed bottom-20 right-6 w-80 rounded-2xl shadow-2xl",
          "animate-in slide-in-from-bottom-4 fade-in duration-300"
        )}
        style={{
          backgroundColor: theme?.colors.card || 'rgba(15, 23, 42, 0.95)',
          border: `1px solid ${theme?.colors.border || 'rgba(51, 65, 85, 0.5)'}`,
          boxShadow: `0 20px 60px rgba(0, 0, 0, 0.3)`,
          pointerEvents: 'auto',
          zIndex: 99999,
        }}
      >
      <div 
        className="p-6 border-b relative overflow-hidden"
        style={{ borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)' }}
      >
        <div 
          className="absolute inset-0 opacity-10"
          style={{
            background: `linear-gradient(135deg, ${theme?.colors.accent?.primary || '#3B82F6'} 0%, ${theme?.colors.accent?.secondary || '#8B5CF6'} 100%)`,
          }}
        />
        <div className="relative z-10 flex items-center justify-between">
          <h2 
            className="text-xl font-bold flex items-center gap-2"
            style={{ color: theme?.colors.text.primary || '#F8FAFC' }}
          >
            <Settings className="w-5 h-5" />
            Configurações
          </h2>
          <button
            onClick={onClose}
            className="p-1 rounded-lg hover:bg-white/10 transition-colors"
            style={{ color: theme?.colors.text.muted || '#94A3B8' }}
          >
            <X className="w-5 h-5" />
          </button>
        </div>
      </div>

      <div className="p-6 space-y-6 max-h-[60vh] overflow-y-auto">
        {/* Efeitos de Câmera */}
        <div className="space-y-3">
          <div className="flex items-center gap-2">
            <Camera className="w-4 h-4" style={{ color: theme?.colors.accent?.primary || '#3B82F6' }} />
            <h3 className="font-semibold" style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>
              Modo Foto / Efeitos de Câmera
            </h3>
          </div>
          <div 
            className="p-4 rounded-lg border cursor-pointer transition-all hover:scale-[1.02]"
            style={{
              backgroundColor: cameraEffects ? `${theme?.colors.accent?.primary || '#3B82F6'}15` : 'rgba(255, 255, 255, 0.05)',
              borderColor: cameraEffects ? `${theme?.colors.accent?.primary || '#3B82F6'}60` : theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
            }}
            onClick={() => handleCameraEffects(!cameraEffects)}
          >
            <div className="flex items-center justify-between mb-3">
              <span style={{ color: theme?.colors.text.secondary || '#CBD5E1' }}>
                {cameraEffects ? 'Ativado' : 'Desativado'}
              </span>
              <div 
                className={cn(
                  "w-12 h-6 rounded-full relative transition-all",
                  cameraEffects ? "bg-blue-500" : "bg-gray-600"
                )}
              >
                <div 
                  className={cn(
                    "absolute top-0.5 w-5 h-5 rounded-full bg-white transition-all shadow-lg",
                    cameraEffects ? "left-6" : "left-0.5"
                  )}
                />
              </div>
            </div>
            {cameraEffects && (
              <div className="grid grid-cols-4 gap-2 mt-3">
                {cameraEffectsOptions.map((effect) => (
                  <button
                    key={effect.value}
                    onClick={(e) => {
                      e.stopPropagation()
                      handleCameraEffectType(effect.value)
                    }}
                    className={cn(
                      "p-2 rounded-lg border transition-all hover:scale-110 text-center",
                      cameraEffectType === effect.value && "ring-2"
                    )}
                    style={{
                      backgroundColor: cameraEffectType === effect.value
                        ? `${theme?.colors.accent?.primary || '#3B82F6'}30`
                        : 'rgba(255, 255, 255, 0.05)',
                      borderColor: cameraEffectType === effect.value
                        ? theme?.colors.accent?.primary || '#3B82F6'
                        : theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
                      boxShadow: cameraEffectType === effect.value
                        ? `0 0 0 2px ${theme?.colors.accent?.primary || '#3B82F6'}40`
                        : 'none',
                    }}
                  >
                    <div className="text-2xl mb-1">{effect.icon}</div>
                    <div 
                      className="text-xs font-medium"
                      style={{ color: theme?.colors.text.primary || '#F8FAFC' }}
                    >
                      {effect.label}
                    </div>
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Modo Streamer */}
        <div className="space-y-3">
          <div className="flex items-center gap-2">
            {streamerMode ? (
              <Music2 className="w-4 h-4" style={{ color: theme?.colors.accent?.primary || '#3B82F6' }} />
            ) : (
              <Music className="w-4 h-4" style={{ color: theme?.colors.accent?.primary || '#3B82F6' }} />
            )}
            <h3 className="font-semibold" style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>
              Modo Streamer
            </h3>
          </div>
          <div 
            className="p-4 rounded-lg border cursor-pointer transition-all hover:scale-[1.02]"
            style={{
              backgroundColor: streamerMode ? `${theme?.colors.accent?.primary || '#3B82F6'}15` : 'rgba(255, 255, 255, 0.05)',
              borderColor: streamerMode ? `${theme?.colors.accent?.primary || '#3B82F6'}60` : theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
            }}
            onClick={() => handleStreamerMode(!streamerMode)}
          >
            <div className="flex items-center justify-between">
              <div>
                <span className="block font-medium mb-1" style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>
                  {streamerMode ? 'Música Desativada' : 'Música Ativada'}
                </span>
                <span className="text-xs" style={{ color: theme?.colors.text.muted || '#94A3B8' }}>
                  {streamerMode ? 'A música será desativada para não aparecer no stream' : 'A música tocará normalmente'}
                </span>
              </div>
              <div 
                className={cn(
                  "w-12 h-6 rounded-full relative transition-all",
                  streamerMode ? "bg-blue-500" : "bg-gray-600"
                )}
              >
                <div 
                  className={cn(
                    "absolute top-0.5 w-5 h-5 rounded-full bg-white transition-all shadow-lg",
                    streamerMode ? "left-6" : "left-0.5"
                  )}
                />
              </div>
            </div>
          </div>
        </div>

        {/* Temas */}
        {allowThemeChange && (
          <div className="space-y-3">
            <div className="flex items-center gap-2">
              <Palette className="w-4 h-4" style={{ color: theme?.colors.accent?.primary || '#3B82F6' }} />
              <h3 className="font-semibold" style={{ color: theme?.colors.text.primary || '#F8FAFC' }}>
                Temas
              </h3>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {Object.entries(availableThemes).map(([themeName, themeData]) => (
                <button
                  key={themeName}
                  onClick={() => handleThemeChange(themeName)}
                  className={cn(
                    "p-4 rounded-lg border transition-all hover:scale-105 text-left relative overflow-hidden",
                    selectedTheme === themeName && "ring-2"
                  )}
                  style={{
                    backgroundColor: selectedTheme === themeName 
                      ? `${themeData.colors.accent?.primary || '#3B82F6'}20` 
                      : themeData.colors.card || 'rgba(255, 255, 255, 0.05)',
                    borderColor: selectedTheme === themeName
                      ? themeData.colors.accent?.primary || '#3B82F6'
                      : themeData.colors.border || 'rgba(51, 65, 85, 0.5)',
                    boxShadow: selectedTheme === themeName
                      ? `0 0 0 2px ${themeData.colors.accent?.primary || '#3B82F6'}40`
                      : 'none',
                  }}
                >
                  {/* Preview das cores do tema */}
                  <div className="flex gap-1 mb-2">
                    <div 
                      className="flex-1 h-3 rounded"
                      style={{ backgroundColor: themeData.colors.accent?.primary || '#3B82F6' }}
                    />
                    <div 
                      className="flex-1 h-3 rounded"
                      style={{ backgroundColor: themeData.colors.accent?.secondary || '#8B5CF6' }}
                    />
                    <div 
                      className="flex-1 h-3 rounded"
                      style={{ backgroundColor: themeData.colors.border || 'rgba(51, 65, 85, 0.5)' }}
                    />
                  </div>
                  <div className="flex items-center justify-between">
                    <span 
                      className="text-sm font-semibold capitalize"
                      style={{ color: themeData.colors.text?.primary || '#F8FAFC' }}
                    >
                      {themeData.name || themeName}
                    </span>
                    {selectedTheme === themeName && (
                      <div 
                        className="w-5 h-5 rounded-full flex items-center justify-center"
                        style={{ backgroundColor: themeData.colors.accent?.primary || '#3B82F6' }}
                      >
                        <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                        </svg>
                      </div>
                    )}
                  </div>
                </button>
              ))}
            </div>
          </div>
        )}

        {!allowThemeChange && (
          <div 
            className="p-4 rounded-lg border"
            style={{
              backgroundColor: 'rgba(255, 255, 255, 0.05)',
              borderColor: theme?.colors.border || 'rgba(51, 65, 85, 0.5)',
            }}
          >
            <div className="flex items-center gap-2">
              <EyeOff className="w-4 h-4" style={{ color: theme?.colors.text.muted || '#94A3B8' }} />
              <span className="text-sm" style={{ color: theme?.colors.text.muted || '#94A3B8' }}>
                A mudança de tema foi desativada pelo servidor
              </span>
            </div>
          </div>
        )}
      </div>
    </div>
    </>
  )
}

