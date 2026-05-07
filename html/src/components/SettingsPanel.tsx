import {
  MriBadge,
  MriButton,
  MriCard,
  MriCardContent,
  MriCardHeader,
  MriColorPicker,
} from '@mriqbox/ui-kit'
import { EyeOff, Music, Music2, Palette, RotateCcw, Settings, X } from 'lucide-react'
import { cn } from '@/lib/utils'
import { isValidHex } from '@/lib/accentColor'

interface SettingsPanelProps {
  onClose: () => void
  accentColor: string
  serverAccentColor: string
  accentColorOverride: string | null
  allowAccentOverride: boolean
  onAccentColorChange: (value: string | null) => void
  streamerMode: boolean
  onStreamerModeChange: (value: boolean) => void
  cameraEffects: boolean
  onCameraEffectsChange: (value: boolean) => void
  cameraEffectType: string
  onCameraEffectTypeChange: (value: string) => void
  locales?: any
}

export function SettingsPanel({
  onClose,
  accentColor,
  serverAccentColor,
  accentColorOverride,
  allowAccentOverride,
  onAccentColorChange,
  streamerMode,
  onStreamerModeChange,
  cameraEffects,
  onCameraEffectsChange,
  cameraEffectType,
  onCameraEffectTypeChange,
  locales = {},
}: SettingsPanelProps) {
  const handleColorChange = (hex: string) => {
    if (!allowAccentOverride) return
    if (!isValidHex(hex)) return
    onAccentColorChange(hex.toUpperCase())
  }

  const resetAccentColor = () => {
    onAccentColorChange(null)
  }

  const hasOverride = accentColorOverride !== null && isValidHex(accentColorOverride)

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
            'mri-panel-chrome w-full max-w-[22rem] rounded-3xl',
            'animate-in zoom-in-95 fade-in duration-300',
          )}
          style={{ pointerEvents: 'auto' }}
        >
          <MriCardHeader className="mri-panel-header space-y-4 px-5 pt-5 pb-0">
            <div className="flex items-start justify-between gap-4">
              <div className="space-y-2">
                <div className="flex items-center gap-2 text-foreground">
                  <Settings className="h-5 w-5" />
                  <h2 className="text-lg font-semibold leading-none">
                    {locales.settings?.title || 'Configurações'}
                  </h2>
                </div>
                <p className="text-sm text-muted-foreground">
                  {locales.settings?.subtitle || 'Ajuste o visual e a experiência de usuário.'}
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
            <div className="rounded-3xl border border-border/70 bg-background/45 p-4">
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
                  : (locales.settings?.streamer_off_description || 'Ao ativar o modo streamer a música do menu de seleção será desativada.')}
              </p>

              <MriButton
                variant={streamerMode ? 'secondary' : 'default'}
                className="h-11 w-full rounded-2xl"
                onClick={() => onStreamerModeChange(!streamerMode)}
              >
                {streamerMode
                  ? (locales.settings?.streamer_disable || 'Desligar modo streamer')
                  : (locales.settings?.streamer_enable || 'Ligar modo streamer')}
              </MriButton>
            </div>

            <div className="rounded-3xl border border-border/70 bg-background/45 p-4">
              <div className="mb-4 flex items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  <Palette className="h-4 w-4 text-primary" />
                  <span className="font-medium text-foreground">
                    {locales.settings?.accent_color_title || 'Cor de destaque'}
                  </span>
                </div>

                {hasOverride && (
                  <MriBadge variant="outline" className="rounded-full px-3 py-1 text-[10px] uppercase tracking-[0.18em]">
                    {locales.settings?.accent_color_custom || 'Personalizada'}
                  </MriBadge>
                )}
              </div>

              {allowAccentOverride ? (
                <>
                  <p className="mb-4 text-sm leading-6 text-muted-foreground">
                    {locales.settings?.accent_color_description
                      || 'Escolha uma cor para os destaques da interface. Reseta para a cor padrão do servidor a qualquer momento.'}
                  </p>

                  <div className="flex items-center gap-3">
                    <MriColorPicker
                      color={accentColor}
                      onChange={handleColorChange}
                      active
                      format="hex"
                    />

                    <div className="min-w-0 flex-1">
                      <p className="font-mono text-sm font-semibold uppercase text-foreground">
                        {accentColor}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {hasOverride
                          ? (locales.settings?.accent_color_local || 'Override local')
                          : (locales.settings?.accent_color_server || 'Padrão do servidor')}
                      </p>
                    </div>

                    {hasOverride && (
                      <MriButton
                        variant="ghost"
                        size="icon"
                        className="h-10 w-10 shrink-0 rounded-2xl"
                        onClick={resetAccentColor}
                        title={locales.settings?.accent_color_reset || 'Resetar para o padrão do servidor'}
                      >
                        <RotateCcw className="h-4 w-4" />
                      </MriButton>
                    )}
                  </div>

                  {hasOverride && serverAccentColor && (
                    <p className="mt-3 text-xs text-muted-foreground">
                      {locales.settings?.accent_color_server_hint || 'Padrão do servidor:'}{' '}
                      <span className="font-mono text-foreground">{serverAccentColor.toUpperCase()}</span>
                    </p>
                  )}
                </>
              ) : (
                <div className="flex items-start gap-3">
                  <span className="mt-0.5 flex h-9 w-9 items-center justify-center rounded-2xl bg-background/60 text-muted-foreground">
                    <EyeOff className="h-4 w-4" />
                  </span>
                  <div className="space-y-1">
                    <p className="font-medium text-foreground">
                      {locales.settings?.accent_color_locked_title || 'Cor controlada pelo servidor'}
                    </p>
                    <p className="text-sm leading-6 text-muted-foreground">
                      {locales.settings?.accent_color_locked_description
                        || 'O servidor desativou a personalização da cor para esta sessão.'}
                    </p>
                  </div>
                </div>
              )}
            </div>

            <div className="rounded-3xl border border-border/70 bg-background/45 p-4">
              <div className="mb-3 flex items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  <span className="font-medium text-foreground">
                    {locales.settings?.camera_effects_title || 'Efeitos de câmera'}
                  </span>
                </div>

                <MriBadge variant={cameraEffects ? 'default' : 'secondary'} className="rounded-full px-3 py-1 text-xs">
                  {cameraEffects
                    ? (locales.settings?.streamer_active || 'Ativado')
                    : (locales.settings?.streamer_inactive || 'Desativado')}
                </MriBadge>
              </div>

              <p className="mb-4 text-sm leading-6 text-muted-foreground">
                {locales.settings?.camera_effects_description
                  || 'Aplica um filtro cinematográfico no preview de personagem.'}
              </p>

              <MriButton
                variant={cameraEffects ? 'secondary' : 'default'}
                className="h-11 w-full rounded-2xl"
                onClick={() => onCameraEffectsChange(!cameraEffects)}
              >
                {cameraEffects
                  ? (locales.settings?.camera_effects_disable || 'Desligar efeitos')
                  : (locales.settings?.camera_effects_enable || 'Ligar efeitos')}
              </MriButton>

              {/* Reservado: trocar tipo de efeito (cinema, noir, ...). Atualmente fixo em 'cinema'. */}
              {cameraEffectType !== 'cinema' && (
                <MriButton
                  variant="ghost"
                  className="mt-2 h-9 w-full rounded-2xl text-xs"
                  onClick={() => onCameraEffectTypeChange('cinema')}
                >
                  {locales.settings?.camera_effects_reset || 'Resetar tipo de efeito'}
                </MriButton>
              )}
            </div>
          </MriCardContent>
        </MriCard>
      </div>
    </>
  )
}
