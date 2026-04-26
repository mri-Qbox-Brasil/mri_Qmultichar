import { useEffect, useMemo, useState } from 'react'
import {
  MriBadge,
  MriButton,
  MriCard,
  MriCardContent,
  MriCardHeader,
  MriSectionHeader,
  MriSelect,
} from '@mriqbox/ui-kit'
import { EyeOff, Music, Music2, Palette, Settings, X } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { UiTheme } from '@/lib/mriTheme'

declare function GetParentResourceName(): string

interface SettingsPanelProps {
  theme: UiTheme | null
  availableThemes: { [key: string]: UiTheme }
  onClose: () => void
  onThemeChange?: (themeName: string) => void
  allowThemeChange?: boolean
}

export function SettingsPanel({
  theme,
  availableThemes,
  onClose,
  onThemeChange,
  allowThemeChange = true,
}: SettingsPanelProps) {
  const [streamerMode, setStreamerMode] = useState(false)
  const [selectedTheme, setSelectedTheme] = useState(theme?.name || 'dark')

  const themeOptions = useMemo(
    () => Object.entries(availableThemes).map(([themeName, themeData]) => ({
      label: themeData.name || themeName,
      value: themeName,
    })),
    [availableThemes],
  )

  useEffect(() => {
    const loadSettings = async () => {
      try {
        const response = await fetch(`https://${GetParentResourceName()}/getSettings`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
        })

        const data = await response.json()

        if (data.success) {
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

  useEffect(() => {
    const matchingTheme = Object.entries(availableThemes).find(([, themeData]) => themeData.name === theme?.name)
    if (matchingTheme) {
      setSelectedTheme(matchingTheme[0])
    }
  }, [availableThemes, theme?.name])

  const pushSettings = (nextTheme: string, nextStreamerMode: boolean) => {
    fetch(`https://${GetParentResourceName()}/updateSettings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        theme: nextTheme,
        streamerMode: nextStreamerMode,
      }),
    }).catch(console.error)
  }

  const handleThemeChange = (themeName: string) => {
    if (!allowThemeChange) return

    setSelectedTheme(themeName)

    if (onThemeChange) {
      onThemeChange(themeName)
    }

    pushSettings(themeName, streamerMode)
  }

  const handleStreamerMode = (enabled: boolean) => {
    setStreamerMode(enabled)
    pushSettings(selectedTheme, enabled)
  }

  return (
    <>
      <div
        className="fixed inset-0 z-[99998] bg-black/35"
        style={{ pointerEvents: 'auto' }}
        onClick={onClose}
      />

      <div className="fixed inset-0 z-[99999] flex items-center justify-center p-4" style={{ pointerEvents: 'none' }}>
        <MriCard
          className={cn(
            'mri-panel-chrome w-full max-w-[22rem] rounded-[2rem]',
            'animate-in zoom-in-95 fade-in duration-300',
          )}
          style={{ pointerEvents: 'auto' }}
        >
          <MriCardHeader className="mri-panel-header space-y-4 p-5">
            <div className="flex items-start justify-between gap-4">
              <div className="space-y-2">
                <MriSectionHeader icon={Settings} title="Configurações" className="!mb-0" />
                <p className="text-sm text-muted-foreground">
                  Ajuste o visual e a experiência de usuario.
                </p>
              </div>

              <MriButton
                variant="ghost"
                size="icon"
                className="h-10 w-10 rounded-2xl"
                onClick={onClose}
              >
                <X className="h-4 w-4" />
              </MriButton>
            </div>
          </MriCardHeader>

          <MriCardContent className="space-y-5 p-5">
            <div className="rounded-[1.5rem] border border-border/70 bg-background/45 p-4">
              <div className="mb-3 flex items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  {streamerMode ? <Music2 className="h-4 w-4 text-primary" /> : <Music className="h-4 w-4 text-primary" />}
                  <span className="font-medium text-foreground">Modo Streamer</span>
                </div>

                <MriBadge variant={streamerMode ? 'default' : 'secondary'} className="rounded-full px-3 py-1 text-xs">
                  {streamerMode ? 'Ativado' : 'Desativado'}
                </MriBadge>
              </div>

              <p className="mb-4 text-sm leading-6 text-muted-foreground">
                {streamerMode
                  ? 'A música da tela foi desativada para não aparecer na transmissão.'
                  : 'A música continuará tocando normalmente enquanto a NUI estiver aberta.'}
              </p>

              <MriButton
                variant={streamerMode ? 'secondary' : 'default'}
                className="h-11 w-full rounded-2xl"
                onClick={() => handleStreamerMode(!streamerMode)}
              >
                {streamerMode ? 'Desligar modo streamer' : 'Ligar modo streamer'}
              </MriButton>
            </div>

            {allowThemeChange ? (
              <div className="rounded-[1.5rem] border border-border/70 bg-background/45 p-4">
                <div className="mb-4 flex items-center gap-2">
                  <Palette className="h-4 w-4 text-primary" />
                  <span className="font-medium text-foreground">Tema da interface</span>
                </div>

                <div className="space-y-4">
                  <MriSelect
                    portal={false}
                    value={selectedTheme}
                    options={themeOptions}
                    onChange={handleThemeChange}
                    placeholder="Selecione um tema"
                    searchPlaceholder="Buscar tema"
                    emptyMessage="Nenhum tema encontrado"
                  />

                  <div className="grid grid-cols-2 gap-3">
                    {Object.entries(availableThemes).map(([themeName, themeData]) => (
                      <button
                        key={themeName}
                        type="button"
                        onClick={() => handleThemeChange(themeName)}
                        className={cn(
                          'rounded-[1.25rem] border p-3 text-left transition-all duration-200',
                          'hover:-translate-y-0.5 hover:shadow-xl hover:shadow-black/15',
                          selectedTheme === themeName
                            ? 'border-primary/50 bg-primary/10'
                            : 'border-border/70 bg-background/35 hover:border-primary/30',
                        )}
                      >
                        <div className="mb-3 flex gap-1.5">
                          <span className="h-2.5 flex-1 rounded-full" style={{ backgroundColor: themeData.colors.accent.primary }} />
                          <span className="h-2.5 flex-1 rounded-full" style={{ backgroundColor: themeData.colors.accent.secondary }} />
                          <span className="h-2.5 flex-1 rounded-full" style={{ backgroundColor: themeData.colors.border }} />
                        </div>

                        <div className="flex items-center justify-between gap-2">
                          <span className="truncate text-sm font-medium text-foreground">
                            {themeData.name || themeName}
                          </span>

                          {selectedTheme === themeName && (
                            <MriBadge variant="default" className="rounded-full px-2 py-0.5 text-[10px] uppercase tracking-[0.18em]">
                              Ativo
                            </MriBadge>
                          )}
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            ) : (
              <div className="rounded-[1.5rem] border border-border/70 bg-background/45 p-4">
                <div className="flex items-start gap-3">
                  <span className="mt-0.5 flex h-9 w-9 items-center justify-center rounded-2xl bg-background/60 text-muted-foreground">
                    <EyeOff className="h-4 w-4" />
                  </span>
                  <div className="space-y-1">
                    <p className="font-medium text-foreground">Mudança de tema indisponível</p>
                    <p className="text-sm leading-6 text-muted-foreground">
                      O servidor desativou a troca manual de tema para esta sessão.
                    </p>
                  </div>
                </div>
              </div>
            )}
          </MriCardContent>
        </MriCard>
      </div>
    </>
  )
}
