import { type ComponentType, useEffect, useRef, useState } from 'react'
import {
  MriBadge,
  MriButton,
  MriCardContent,
  MriScrollArea,
} from '@mriqbox/ui-kit'
import {
  Briefcase,
  Building2,
  Calendar,
  Crown,
  Play,
  Settings,
  Shield,
  Trash2,
  User,
  Wallet,
  X,
} from 'lucide-react'
import { CharacterCreation } from './components/CharacterCreation'
import { CharacterList } from './components/CharacterList'
import { DeleteConfirmDialog } from './components/DeleteConfirmDialog'
import { GlitchName } from './components/GlitchName'
import { MusicPlayer } from './components/MusicPlayer'
import { SettingsPanel } from './components/SettingsPanel'
import { Avatar, AvatarFallback, AvatarImage } from './components/ui/avatar'

import { applyAccentColor, isValidHex } from './lib/accentColor'
import { useLocalSettings } from './lib/useLocalSettings'
import { formatNumber } from './utils/formatNumber'

declare function GetParentResourceName(): string

const FALLBACK_ACCENT = '#00E699'

export interface Character {
  citizenid: string
  charinfo: {
    firstname: string
    lastname: string
    gender: number
    birthdate: string
    nationality: string
    account: string
    phone: string
  }
  money: {
    bank: number
    cash: number
  }
  job: {
    name?: string
    label: string
    grade: number | { name: string }
  }
  gang: {
    label: string
    grade: { name: string }
  }
  cid?: number
  photo?: string
}

interface MusicConfig {
  enabled: boolean
  url: string
  volume: number
  loop: boolean
  autoplay: boolean
}

interface ServerDefaults {
  streamerMode?: boolean
  cameraEffects?: boolean
  cameraEffectType?: string
}

interface InfoTileProps {
  icon: ComponentType<{ className?: string }>
  label: string
  value: string
}

function InfoTile({ icon: Icon, label, value }: InfoTileProps) {
  return (
    <div className="rounded-2xl border border-border/80 bg-card p-3">
      <div className="mb-2 flex items-center gap-2 text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
        <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-background">
          <Icon className="h-3.5 w-3.5" />
        </span>
        <span>{label}</span>
      </div>
      <p className="truncate text-sm font-semibold text-foreground sm:text-base">{value}</p>
    </div>
  )
}

function App() {
  const [isOpen, setIsOpen] = useState(false)
  const [characters, setCharacters] = useState<Character[]>([])
  const [maxSlots, setMaxSlots] = useState(3)
  const [selectedCharacter, setSelectedCharacter] = useState<Character | null>(null)
  const [showCreation, setShowCreation] = useState(false)
  const [creatingSlot, setCreatingSlot] = useState<number | null>(null)
  const [music, setMusic] = useState<MusicConfig | null>(null)
  const [showDeleteDialog, setShowDeleteDialog] = useState(false)
  const [characterToDelete, setCharacterToDelete] = useState<Character | null>(null)
  const [selectedCharacterPhoto, setSelectedCharacterPhoto] = useState<string | null>(null)
  const [showSettings, setShowSettings] = useState(false)
  const [characterPhotos, setCharacterPhotos] = useState<Record<string, string>>({})
  const [locales, setLocales] = useState<any>({})
  const [statusMessage, setStatusMessage] = useState<string | null>(null)

  const [serverAccentColor, setServerAccentColor] = useState<string>(FALLBACK_ACCENT)
  const [allowAccentOverride, setAllowAccentOverride] = useState(true)
  const [serverDefaults, setServerDefaults] = useState<ServerDefaults>({})

  const {
    settings,
    setStreamerMode,
    setCameraEffects,
    setCameraEffectType,
    setAccentColorOverride,
  } = useLocalSettings(serverDefaults)

  const effectiveAccentColor = allowAccentOverride && settings.accentColorOverride
    ? settings.accentColorOverride
    : serverAccentColor

  const musicRef = useRef(music)
  const selectedCharacterRef = useRef(selectedCharacter)

  const getPreferredCharacter = (nextCharacters: Character[]) =>
    nextCharacters[0] ?? null

  const captureTxdAsBase64 = (txd: string, citizenid: string) => {
    const url = `https://nui-img/${txd}/${txd}?v=${Date.now()}`
    const img = new Image()
    img.crossOrigin = 'anonymous'

    const finalize = (dataUrl: string | null) => {
      if (!dataUrl) {
        console.error('[mri_Qmultichar] captureTxdAsBase64: falha ao gerar base64', { txd, citizenid })
        return
      }

      setCharacterPhotos((prev) => ({ ...prev, [citizenid]: dataUrl }))
      if (selectedCharacterRef.current?.citizenid === citizenid) {
        setSelectedCharacterPhoto(dataUrl)
      }

      fetch(`https://${GetParentResourceName()}/savePhotoBase64`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ citizenid, photo: dataUrl }),
      }).catch(console.error)
    }

    img.onload = () => {
      try {
        const canvas = document.createElement('canvas')
        canvas.width = img.naturalWidth || 96
        canvas.height = img.naturalHeight || 96
        const ctx = canvas.getContext('2d')
        if (!ctx) {
          finalize(null)
          return
        }
        ctx.drawImage(img, 0, 0)
        finalize(canvas.toDataURL('image/png'))
      } catch (error) {
        console.error('[mri_Qmultichar] captureTxdAsBase64: erro de canvas', error)
        finalize(null)
      }
    }
    img.onerror = (error) => {
      console.error('[mri_Qmultichar] captureTxdAsBase64: erro ao carregar nui-img', error, { url })
      finalize(null)
    }
    img.src = url
  }

  const requestPreviewForCharacter = (character: Character | null) => {
    if (!character) {
      return
    }

    const jobName = character.job?.name || (character.job?.label ? character.job.label.toLowerCase().replace(/\s+/g, '') : 'unemployed')

    fetch(`https://${GetParentResourceName()}/getPreviewData`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        citizenid: character.citizenid,
        job: jobName,
      }),
    }).catch(console.error)
  }

  const applyCharacters = (nextCharacters: Character[]) => {
    setCharacters(nextCharacters)

    const photosFromServer: Record<string, string> = {}
    for (const character of nextCharacters) {
      if (character.photo) {
        photosFromServer[character.citizenid] = character.photo
      }
    }
    if (Object.keys(photosFromServer).length > 0) {
      setCharacterPhotos((prev) => ({ ...prev, ...photosFromServer }))
    }

    const preferredCharacter = getPreferredCharacter(nextCharacters)
    setSelectedCharacter(preferredCharacter)
    const preferredPhoto = preferredCharacter
      ? photosFromServer[preferredCharacter.citizenid] || characterPhotos[preferredCharacter.citizenid] || preferredCharacter.photo || null
      : null
    setSelectedCharacterPhoto(preferredPhoto)

    requestPreviewForCharacter(preferredCharacter)
  }

  useEffect(() => {
    musicRef.current = music
  }, [music])

  useEffect(() => {
    selectedCharacterRef.current = selectedCharacter
  }, [selectedCharacter])

  useEffect(() => {
    if (isValidHex(effectiveAccentColor)) {
      applyAccentColor(effectiveAccentColor)
    }
  }, [effectiveAccentColor])

  // Dispara o export Lua que aplica o timecycle modifier do preview cam.
  useEffect(() => {
    fetch(`https://${GetParentResourceName()}/setCameraEffects`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        enabled: settings.cameraEffects,
        effectType: settings.cameraEffectType,
      }),
    }).catch(() => {})
  }, [settings.cameraEffects, settings.cameraEffectType])

  useEffect(() => {
    fetch(`https://${GetParentResourceName()}/nuiStarted`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    }).catch(console.error)

    const handleMessage = (event: MessageEvent) => {
      const data = event.data

      if (data && data.action === 'open') {
        if (data.locales) setLocales(data.locales)
        if (typeof data.accentColor === 'string' && isValidHex(data.accentColor)) {
          setServerAccentColor(data.accentColor)
        }
        if (typeof data.allowAccentOverride === 'boolean') {
          setAllowAccentOverride(data.allowAccentOverride)
        }
        if (data.defaults && typeof data.defaults === 'object') {
          setServerDefaults(data.defaults)
        }
        if (data.music) setMusic(data.music)

        if (data.characters) {
          applyCharacters(data.characters)
          setMaxSlots(data.amount || 3)
          setStatusMessage(null)
        } else {
          loadCharacters()
        }

        setIsOpen(true)
      } else if (data && data.action === 'close') {
        setIsOpen(false)
        setSelectedCharacter(null)
        setStatusMessage(null)
        setShowCreation(false)
        setShowSettings(false)
      } else if (data && data.action === 'refreshCharacters') {
        setTimeout(() => {
          loadCharacters()
        }, 300)
      } else if (data && data.action === 'updateAccentColor') {
        if (typeof data.accentColor === 'string' && isValidHex(data.accentColor)) {
          setServerAccentColor(data.accentColor)
        }
      } else if (data && data.action === 'characterPhotoReady') {
        if (data.photo) {
          setCharacterPhotos((prev) => ({
            ...prev,
            [data.citizenid]: data.photo,
          }))

          if (selectedCharacterRef.current && selectedCharacterRef.current.citizenid === data.citizenid) {
            setSelectedCharacterPhoto(data.photo)
          }
        }
      } else if (data && data.action === 'captureBase64') {
        if (typeof data.txd === 'string' && typeof data.citizenid === 'string') {
          captureTxdAsBase64(data.txd, data.citizenid)
        }
      }
    }

    window.addEventListener('message', handleMessage)
    return () => window.removeEventListener('message', handleMessage)
  }, [])

  const loadCharacters = () => {
    fetch(`https://${GetParentResourceName()}/getCharacters`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    })
      .then((res) => {
        if (!res.ok) {
          throw new Error(`HTTP error! status: ${res.status}`)
        }

        return res.json()
      })
      .then((data) => {
        if (data && data.success) {
          applyCharacters(data.characters || [])
          setMaxSlots(data.amount || 3)
          setStatusMessage(null)

          if (typeof data.accentColor === 'string' && isValidHex(data.accentColor)) {
            setServerAccentColor(data.accentColor)
          }
          if (typeof data.allowAccentOverride === 'boolean') {
            setAllowAccentOverride(data.allowAccentOverride)
          }
          if (data.defaults && typeof data.defaults === 'object') {
            setServerDefaults(data.defaults)
          }
          if (data.music) {
            setMusic(data.music)
          }
          if (data.locales) {
            setLocales(data.locales)
          }
        } else {
          console.error('[mri_Qmultichar] Erro ao carregar personagens:', data)
          setCharacters([])
          setMaxSlots(3)
        }
      })
      .catch((err) => {
        console.error('[mri_Qmultichar] Erro ao carregar personagens:', err)
        setCharacters([])
        setMaxSlots(3)
      })
  }

  const handleLoadCharacter = (citizenid: string) => {
    setStatusMessage(null)

    fetch(`https://${GetParentResourceName()}/loadCharacter`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ citizenid }),
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.success) {
          setIsOpen(false)
        } else {
          setStatusMessage(data.message || locales.characters?.load_failed)
        }
      })
      .catch((err) => {
        console.error('Erro ao carregar personagem:', err)
        setStatusMessage(locales.characters?.error_loading_character ?? null)
      })
  }

  const handleDeleteCharacter = (citizenid: string) => {
    const character = characters.find((candidate) => candidate.citizenid === citizenid)
    setCharacterToDelete(character || null)
    setShowDeleteDialog(true)
  }

  const confirmDelete = () => {
    if (!characterToDelete) return

    fetch(`https://${GetParentResourceName()}/deleteCharacter`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ citizenid: characterToDelete.citizenid }),
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.success) {
          setTimeout(() => {
            loadCharacters()
            setSelectedCharacter(null)
            setShowDeleteDialog(false)
            setCharacterToDelete(null)
          }, 1500)
        }
      })
      .catch((err) => console.error('Erro ao deletar personagem:', err))
  }

  const handleCreateCharacter = (slot: number) => {
    setCreatingSlot(slot)
    setShowCreation(true)
    setSelectedCharacter(null)
    setStatusMessage(null)
  }

  const handleCharacterCreated = () => {
    setShowCreation(false)
    setCreatingSlot(null)
    setStatusMessage(null)
  }

  const handleCharacterSelect = (character: Character) => {
    setSelectedCharacter(character)
    setShowCreation(false)
    setStatusMessage(null)

    fetch(`https://${GetParentResourceName()}/getCharacterPhoto`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ citizenid: character.citizenid }),
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.success && data.photo) {
          setSelectedCharacterPhoto(data.photo)
        } else {
          setSelectedCharacterPhoto(null)
        }
      })
      .catch(() => setSelectedCharacterPhoto(null))

    const jobName = character.job?.name || (character.job?.label ? character.job.label.toLowerCase().replace(/\s+/g, '') : 'unemployed')

    fetch(`https://${GetParentResourceName()}/getPreviewData`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        citizenid: character.citizenid,
        job: jobName,
      }),
    }).catch((err) => console.error('Erro ao obter preview:', err))
  }

  if (!isOpen) {
    return null
  }

  const selectedPhoto = selectedCharacter ? selectedCharacterPhoto || characterPhotos[selectedCharacter.citizenid] : null
  const selectedGrade = selectedCharacter
    ? typeof selectedCharacter.job?.grade === 'object'
      ? selectedCharacter.job.grade.name
      : String(selectedCharacter.job?.grade || '0')
    : '0'

  if (showCreation) {
    return (
      <div className="mri-app-shell">
        <div className="fixed inset-0 z-10 flex items-center justify-center p-4" style={{ pointerEvents: 'none' }}>
          <div style={{ pointerEvents: 'auto' }}>
            <CharacterCreation
              slot={creatingSlot || 1}
              locales={locales}
              onCancel={() => {
                setShowCreation(false)
                setCreatingSlot(null)
              }}
              onSuccess={handleCharacterCreated}
            />
          </div>
        </div>
        <div className="fixed bottom-0 left-0 right-0 z-[10001] flex justify-center px-4 pb-5">
          <MusicPlayer music={music || undefined} isStreamerMode={settings.streamerMode} locales={locales} />
        </div>
      </div>
    )
  }

  return (
    <div className="mri-app-shell">
      <div className="relative flex h-full items-start justify-between gap-6 px-6 pt-4 pb-8" style={{ pointerEvents: 'none' }}>
        <div
          className="flex h-fit w-[26rem] max-w-[26rem] flex-col self-center overflow-visible"
          style={{ pointerEvents: 'auto' }}
        >
          <MriCardContent className="flex-1 overflow-hidden p-0">
            <MriScrollArea className="h-full">
              <CharacterList
                characters={characters}
                maxSlots={maxSlots}
                selectedCharacter={selectedCharacter}
                onSelect={handleCharacterSelect}
                onCreate={handleCreateCharacter}
                characterPhotos={characterPhotos}
                locales={locales}
              />
            </MriScrollArea>
          </MriCardContent>
        </div>

        <div
          className="preview-area relative flex min-h-[600px] flex-1 flex-col items-center justify-start"
          style={{ background: 'transparent', pointerEvents: 'none' }}
        >
          {selectedCharacter && (
            <div
              className="absolute left-1/2 top-5 z-[1000] flex w-full max-w-[32rem] -translate-x-1/2 flex-col items-center gap-3 px-6"
              style={{ pointerEvents: 'none' }}
            >
              <GlitchName
                name={`${selectedCharacter.charinfo.firstname} ${selectedCharacter.charinfo.lastname}`}
                accentColor={effectiveAccentColor}
              />
            </div>
          )}
        </div>

        <div
          className="flex h-fit w-[26rem] max-w-[26rem] flex-col self-center overflow-visible"
          style={{ pointerEvents: 'auto' }}
        >
          {selectedCharacter ? (
            <div className="space-y-4 rounded-3xl border border-border/80 bg-card p-5">
              <div className="flex items-start gap-4">
                <Avatar className="h-24 w-24 rounded-3xl border-2 border-primary bg-background">
                  {selectedPhoto ? (
                    <AvatarImage
                      src={selectedPhoto}
                      alt={`${selectedCharacter.charinfo.firstname} ${selectedCharacter.charinfo.lastname}`}
                      className="object-cover"
                    />
                  ) : null}
                  <AvatarFallback className="rounded-2xl bg-background text-2xl font-bold text-foreground">
                    {selectedCharacter.charinfo.firstname[0]}
                    {selectedCharacter.charinfo.lastname[0]}
                  </AvatarFallback>
                </Avatar>

                <div className="min-w-0 flex-1 space-y-3">
                  <div>
                    <h3 className="truncate text-2xl font-semibold text-foreground">
                      {selectedCharacter.charinfo.firstname} {selectedCharacter.charinfo.lastname}
                    </h3>
                    <p className="mt-1 text-sm text-muted-foreground">
                      {selectedCharacter.job?.label || locales.characters?.unemployed}
                    </p>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <MriBadge variant="outline" className="rounded-full px-3 py-1 text-xs font-medium">
                      <Shield className="mr-1 h-3.5 w-3.5" />
                      {selectedCharacter.citizenid}
                    </MriBadge>
                    <MriBadge variant="secondary" className="rounded-full px-3 py-1 text-xs font-medium">
                      <Crown className="mr-1 h-3.5 w-3.5" />
                      {selectedGrade}
                    </MriBadge>
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2">
                <InfoTile
                  icon={Wallet}
                  label={locales.characters?.cash}
                  value={`$${formatNumber(selectedCharacter.money?.cash || 0)}`}
                />
                <InfoTile
                  icon={Building2}
                  label={locales.characters?.bank}
                  value={`$${formatNumber(selectedCharacter.money?.bank || 0)}`}
                />
                <InfoTile
                  icon={Briefcase}
                  label={locales.characters?.job}
                  value={selectedCharacter.job?.label || locales.characters?.unemployed}
                />
                <InfoTile
                  icon={Crown}
                  label={locales.characters?.grade}
                  value={selectedGrade}
                />
                <InfoTile
                  icon={User}
                  label={locales.characters?.gender}
                  value={selectedCharacter.charinfo.gender === 0
                    ? locales.characters?.male
                    : locales.characters?.female}
                />
                <InfoTile
                  icon={Calendar}
                  label={locales.characters?.birthdate}
                  value={selectedCharacter.charinfo.birthdate}
                />
                <InfoTile
                  icon={User}
                  label={locales.characters?.nationality}
                  value={selectedCharacter.charinfo.nationality}
                />
                <InfoTile
                  icon={Shield}
                  label={locales.characters?.gang}
                  value={selectedCharacter.gang?.label}
                />
              </div>

              <div className="space-y-3 pt-1">
                {statusMessage && (
                  <div className="rounded-2xl border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive-foreground">
                    {statusMessage}
                  </div>
                )}

                <MriButton
                  className="h-12 w-full rounded-2xl text-sm font-semibold shadow-lg shadow-black/20"
                  onClick={() => handleLoadCharacter(selectedCharacter.citizenid)}
                >
                  <Play className="mr-2 h-4 w-4" />
                  {locales.buttons?.choose_character}
                </MriButton>

                <MriButton
                  variant="destructive"
                  className="h-12 w-full rounded-2xl text-sm font-semibold shadow-lg shadow-black/20"
                  onClick={() => handleDeleteCharacter(selectedCharacter.citizenid)}
                >
                  <Trash2 className="mr-2 h-4 w-4" />
                  {locales.buttons?.delete}
                </MriButton>
              </div>
            </div>
          ) : (
            <div className="w-full rounded-3xl border border-dashed border-border/80 bg-card p-10 text-center">
              <div className="mx-auto mb-5 flex h-20 w-20 items-center justify-center rounded-3xl border border-primary/25 bg-primary/10 text-primary">
                <User className="h-9 w-9" />
              </div>
              <h3 className="text-xl font-semibold text-foreground">
                {locales.characters?.select_character}
              </h3>
              <p className="mt-2 text-sm text-muted-foreground">
                {locales.characters?.select_or_create}
              </p>
            </div>
          )}
        </div>
      </div>

      <div className="fixed bottom-0 left-0 right-0 z-[10000] flex justify-center px-4 pb-5" style={{ pointerEvents: 'auto' }}>
        <MusicPlayer music={music || undefined} isStreamerMode={settings.streamerMode} locales={locales} />
      </div>

      <MriButton
        size="icon"
        className="fixed bottom-6 right-6 z-[99999] h-14 w-14 rounded-full shadow-2xl shadow-black/30"
        style={{ pointerEvents: 'auto' }}
        onClick={(event) => {
          event.stopPropagation()
          setShowSettings(!showSettings)
        }}
      >
        {showSettings ? <X className="h-5 w-5" /> : <Settings className="h-5 w-5" />}
      </MriButton>

      {showSettings && (
        <SettingsPanel
          onClose={() => setShowSettings(false)}
          accentColor={effectiveAccentColor}
          serverAccentColor={serverAccentColor}
          accentColorOverride={settings.accentColorOverride}
          allowAccentOverride={allowAccentOverride}
          onAccentColorChange={setAccentColorOverride}
          streamerMode={settings.streamerMode}
          onStreamerModeChange={setStreamerMode}
          cameraEffects={settings.cameraEffects}
          onCameraEffectsChange={setCameraEffects}
          cameraEffectType={settings.cameraEffectType}
          onCameraEffectTypeChange={setCameraEffectType}
          locales={locales}
        />
      )}

      <DeleteConfirmDialog
        open={showDeleteDialog}
        onClose={() => {
          setShowDeleteDialog(false)
          setCharacterToDelete(null)
        }}
        onConfirm={confirmDelete}
        characterName={characterToDelete ? `${characterToDelete.charinfo.firstname} ${characterToDelete.charinfo.lastname}` : undefined}
        locales={locales}
      />
    </div>
  )
}

export default App
