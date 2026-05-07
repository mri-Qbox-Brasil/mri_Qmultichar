import { useEffect, useMemo, useState } from 'react'
import {
  MriBadge,
  MriButton,
  MriCard,
  MriCardContent,
  MriCardHeader,
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
  locales?: any
}

export function SettingsPanel({
  theme,
  availableThemes,
  onClose,
  onThemeChange,
  allowThemeChange = true,
  locales = {},
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
          <MriCardHeader className="mri-panel-header space-y-4 px-5 pt-5 pb-0">
            <div className="flex items-start justify-between gap-4">
              <div className="space-y-2">
                <div className="flex items-center gap-2 text-white">
                  <Settings className="h-5 w-5" />
                  <h2 className="text-lg font-semibold leading-none">
                    {locales.settings?.title || 'Configurações'}
                  </h2>
                </div>
                <p className="text-sm text-muted-foreground">
                  {locales.settings?.subtitle || 'Ajuste o visual e a experiência de usuario.'}
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

          <MriCardContent className="space-y-5 px-5 pb-5 pt-2">
            <div className="rounded-[1.5rem] border border-border/70 bg-background/45 p-4">
              <div className="mb-3 flex items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  {streamerMode ? <Music2 className="h-4 w-4 text-primary" /> : <Music className="h-4 w-4 text-primary" />}
                  <span className="font-medium text-foreground">
                    {locales.settings?.streamer_mode_title || 'Modo Streamer'}
                  </span>
                </div>

                <MriBadge variant={streamerMode ? 'default' : 'secondary'} className="rounded-full px-3 py-1 text-xs">
                  {streamerMode
                    ? (locales.settings?.streamer_active || 'Ativado')
                    : (locales.settings?.streamer_inactive || 'Desativado')}
                </MriBadge>
              </div>

              <p className="mb-4 text-sm leading-6 text-muted-foreground">
                {streamerMode
                  ? (locales.settings?.streamer_on_description || 'A música da tela foi desativada para não aparecer na transmissão.')
                  : (locales.settings?.streamer_off_description || 'Ao ativar o modo streamer a musica do seu menu de selecao de personagem sera desativada')}
              </p>

              <MriButton
                variant={streamerMode ? 'secondary' : 'default'}
                className="h-11 w-full rounded-2xl"
                onClick={() => handleStreamerMode(!streamerMode)}
              >
                {streamerMode
                  ? (locales.settings?.streamer_disable || 'Desligar modo streamer')
                  : (locales.settings?.streamer_enable || 'Ligar modo streamer')}
              </MriButton>
            </div>

            {allowThemeChange ? (
              <div className="rounded-[1.5rem] border border-border/70 bg-background/45 p-4">
                <div className="mb-4 flex items-center gap-2">
                  <Palette className="h-4 w-4 text-primary" />
                  <span className="font-medium text-foreground">
                    {locales.settings?.theme_section_title || 'Tema da interface'}
                  </span>
                </div>

                <div className="space-y-4">
                  <MriSelect
                    portal={false}
                    value={selectedTheme}
                    options={themeOptions}
                    onChange={handleThemeChange}
                    placeholder={locales.settings?.theme_select_placeholder || 'Selecione um tema'}
                    searchPlaceholder={locales.settings?.theme_search_placeholder || 'Buscar tema'}
                    emptyMessage={locales.settings?.theme_empty || 'Nenhum tema encontrado'}
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
                              {locales.settings?.theme_active_badge || 'Ativo'}
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
                    <p className="font-medium text-foreground">
                      {locales.settings?.theme_locked_title || 'Mudança de tema indisponível'}
                    </p>
                    <p className="text-sm leading-6 text-muted-foreground">
                      {locales.settings?.theme_locked_description || 'O servidor desativou a troca manual de tema para esta sessão.'}
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
