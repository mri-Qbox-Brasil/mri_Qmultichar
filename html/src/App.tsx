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

import { getMriThemeVars, type UiTheme } from './lib/mriTheme'
import { formatNumber } from './utils/formatNumber'

declare function GetParentResourceName(): string

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

type Theme = UiTheme

interface MusicConfig {
  enabled: boolean
  url: string
  volume: number
  loop: boolean
  autoplay: boolean
}

interface InfoTileProps {
  icon: ComponentType<{ className?: string }>
  label: string
  value: string
}

function InfoTile({ icon: Icon, label, value }: InfoTileProps) {
  return (
    <div
      className="rounded-2xl border p-3"
      style={{ 
        background: '#0f1115', 
        backgroundColor: '#0f1115',
        opacity: 1,
        transform: 'translateZ(0)'
      }}
    >
      <div className="mb-2 flex items-center gap-2 text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
        <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-black">
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
  const [theme, setTheme] = useState<Theme | null>(null)
  const [music, setMusic] = useState<MusicConfig | null>(null)
  const [showDeleteDialog, setShowDeleteDialog] = useState(false)
  const [characterToDelete, setCharacterToDelete] = useState<Character | null>(null)
  const [selectedCharacterPhoto, setSelectedCharacterPhoto] = useState<string | null>(null)
  const [showSettings, setShowSettings] = useState(false)
  const [allowThemeChange, setAllowThemeChange] = useState(true)
  const [availableThemes, setAvailableThemes] = useState<{ [key: string]: Theme }>({})
  const [streamerMode, setStreamerMode] = useState(false)
  const [characterPhotos, setCharacterPhotos] = useState<Record<string, string>>({})
  const [locales, setLocales] = useState<any>({})
  const [statusMessage, setStatusMessage] = useState<string | null>(null)
  const availableThemesRef = useRef(availableThemes)
  const musicRef = useRef(music)
  const selectedCharacterRef = useRef(selectedCharacter)

  const getPreferredCharacter = (nextCharacters: Character[]) =>
    nextCharacters[0] ?? null

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

    const preferredCharacter = getPreferredCharacter(nextCharacters)
    setSelectedCharacter(preferredCharacter)
    setSelectedCharacterPhoto(preferredCharacter ? characterPhotos[preferredCharacter.citizenid] || null : null)

    requestPreviewForCharacter(preferredCharacter)
  }

  useEffect(() => {
    availableThemesRef.current = availableThemes
  }, [availableThemes])

  useEffect(() => {
    musicRef.current = music
  }, [music])

  useEffect(() => {
    selectedCharacterRef.current = selectedCharacter
  }, [selectedCharacter])

  useEffect(() => {
    console.log('[mri_Qmultichar] Enviando handshake nuiStarted...')
    fetch(`https://${GetParentResourceName()}/nuiStarted`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    }).catch(console.error)

    const handleMessage = (event: MessageEvent) => {
      const data = event.data

      if (data && data.action === 'open') {
        if (data.locales) setLocales(data.locales)
        if (data.availableThemes) setAvailableThemes(data.availableThemes)
        if (data.theme) setTheme(data.theme)
        if (data.music) setMusic(data.music)
        if (data.allowThemeChange !== undefined) setAllowThemeChange(data.allowThemeChange)
        if (data.streamerMode !== undefined) setStreamerMode(data.streamerMode)

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
      } else if (data && data.action === 'setStreamerMode') {
        setStreamerMode(data.enabled)

        if (data.enabled && musicRef.current) {
          setMusic({ ...musicRef.current, enabled: false })
        } else if (!data.enabled && musicRef.current) {
          setMusic({ ...musicRef.current, enabled: true })
        }
      } else if (data && data.action === 'updateTheme') {
        if (availableThemesRef.current[data.theme]) {
          setTheme(availableThemesRef.current[data.theme])
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

          if (data.theme) {
            setTheme(data.theme)
          }

          if (data.music) {
            setMusic(data.music)
          }

          if (data.allowThemeChange !== undefined) {
            setAllowThemeChange(data.allowThemeChange)
          }

          if (data.availableThemes) {
            setAvailableThemes(data.availableThemes)
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
          setStatusMessage(data.message || 'Nao foi possivel carregar este personagem.')
        }
      })
      .catch((err) => {
        console.error('Erro ao carregar personagem:', err)
        setStatusMessage('Erro ao carregar personagem.')
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
      <div className="mri-app-shell" style={getMriThemeVars(theme)}>
        <div className="fixed inset-0 z-10 flex items-center justify-center p-4" style={{ pointerEvents: 'none' }}>
          <div style={{ pointerEvents: 'auto' }}>
            <CharacterCreation
            slot={creatingSlot || 1}
            theme={theme}
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
          <MusicPlayer music={music || undefined} theme={theme || undefined} isStreamerMode={streamerMode} />
        </div>
      </div>
    )
  }

  return (
    <div className="mri-app-shell" style={getMriThemeVars(theme)}>
      <div className="relative flex h-full items-start justify-between gap-6 px-6 pt-4 pb-8" style={{ pointerEvents: 'none' }}>
        <div
          className="flex h-fit w-[25rem] max-w-[25rem] flex-col self-center overflow-visible"
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
                theme={theme}
                characterPhotos={characterPhotos}
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
              <MriBadge
                variant="outline"
                className="rounded-full border-primary/30 bg-black px-4 py-1.5 text-xs uppercase tracking-[0.22em] text-primary"
                style={{ opacity: 1 }}
              >
                Preview Ativo
              </MriBadge>
              <GlitchName
                name={`${selectedCharacter.charinfo.firstname} ${selectedCharacter.charinfo.lastname}`}
                theme={theme || undefined}
              />
            </div>
          )}
        </div>

        <div
          className="flex h-fit w-[26rem] max-w-[26rem] flex-col self-center overflow-visible"
          style={{ pointerEvents: 'auto' }}
        >
          {selectedCharacter ? (
            <div
              className="space-y-4 rounded-[1.9rem] border border-border/80 p-5"
              style={{ backgroundColor: 'rgb(15, 17, 21)', opacity: 1 }}
            >
              <div className="flex items-start gap-4">
                <Avatar className="h-24 w-24 rounded-[1.5rem] border-2 border-primary bg-black">
                  {selectedPhoto ? (
                    <AvatarImage
                      src={selectedPhoto}
                      alt={`${selectedCharacter.charinfo.firstname} ${selectedCharacter.charinfo.lastname}`}
                      className="object-cover"
                    />
                  ) : null}
                  <AvatarFallback className="rounded-[1.35rem] bg-[#0f1115]/95 text-2xl font-bold text-foreground">
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
                      {selectedCharacter.job?.label || (locales.characters?.unemployed || 'UNEMPLOYED')}
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
                  label={locales.characters?.cash || 'Cash'}
                  value={`$${formatNumber(selectedCharacter.money?.cash || 0)}`}
                />
                <InfoTile
                  icon={Building2}
                  label={locales.characters?.bank || 'Bank'}
                  value={`$${formatNumber(selectedCharacter.money?.bank || 0)}`}
                />
                <InfoTile
                  icon={Briefcase}
                  label={locales.characters?.job || 'Job'}
                  value={selectedCharacter.job?.label || (locales.characters?.unemployed || 'UNEMPLOYED')}
                />
                <InfoTile
                  icon={Crown}
                  label={locales.characters?.grade || 'Grade'}
                  value={selectedGrade}
                />
                <InfoTile
                  icon={User}
                  label={locales.characters?.gender || 'Gender'}
                  value={selectedCharacter.charinfo.gender === 0
                    ? (locales.characters?.male || 'Male')
                    : (locales.characters?.female || 'Female')}
                />
                <InfoTile
                  icon={Calendar}
                  label={locales.characters?.birthdate || 'Birthdate'}
                  value={selectedCharacter.charinfo.birthdate || 'N/A'}
                />
                <InfoTile
                  icon={User}
                  label={locales.characters?.nationality || 'Nationality'}
                  value={selectedCharacter.charinfo.nationality || 'N/A'}
                />
                <InfoTile
                  icon={Shield}
                  label={locales.characters?.gang || 'Gang'}
                  value={selectedCharacter.gang?.label || 'N/A'}
                />
              </div>

              <div className="space-y-3 pt-1">
                {statusMessage && (
                  <div className="rounded-2xl border border-red-500/30 bg-[#14080a]/95 px-3 py-2 text-sm text-red-100">
                    {statusMessage}
                  </div>
                )}

                <MriButton
                  className="h-12 w-full rounded-2xl text-sm font-semibold shadow-lg shadow-black/20"
                  onClick={() => handleLoadCharacter(selectedCharacter.citizenid)}
                >
                  <Play className="mr-2 h-4 w-4" />
                  {locales.buttons?.choose_character || 'Choose Character'}
                </MriButton>

                <MriButton
                  variant="destructive"
                  className="h-12 w-full rounded-2xl text-sm font-semibold shadow-lg shadow-black/20"
                  onClick={() => handleDeleteCharacter(selectedCharacter.citizenid)}
                >
                  <Trash2 className="mr-2 h-4 w-4" />
                  {locales.buttons?.delete || 'Delete Character'}
                </MriButton>
              </div>
            </div>
          ) : (
            <div
              className="w-full rounded-[1.9rem] border border-dashed border-border/80 p-10 text-center"
              style={{ backgroundColor: 'rgb(15, 17, 21)', opacity: 1 }}
            >
              <div className="mx-auto mb-5 flex h-20 w-20 items-center justify-center rounded-[1.75rem] border border-primary/25 bg-primary/10 text-primary">
                <User className="h-9 w-9" />
              </div>
              <h3 className="text-xl font-semibold text-foreground">
                {locales.characters?.select_character || 'Select a character'}
              </h3>
              <p className="mt-2 text-sm text-muted-foreground">
                {locales.characters?.select_or_create || 'Escolha um slot na lista ou crie um novo personagem.'}
              </p>
            </div>
          )}
        </div>
      </div>

      <div className="fixed bottom-0 left-0 right-0 z-[10000] flex justify-center px-4 pb-5" style={{ pointerEvents: 'auto' }}>
        <MusicPlayer music={music || undefined} theme={theme || undefined} isStreamerMode={streamerMode} />
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
          theme={theme}
          availableThemes={availableThemes}
          onClose={() => setShowSettings(false)}
          onThemeChange={(themeName) => {
            if (availableThemes[themeName]) {
              setTheme(availableThemes[themeName])
            }
          }}
          allowThemeChange={allowThemeChange}
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
        theme={theme}
      />
    </div>
  )
}

export default App
